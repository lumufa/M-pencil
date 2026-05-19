import bluetoothManager from '@ohos.bluetoothManager';

export type MonitorSource = 'mock' | 'ble';
export type NativeStrategy = 'vendor-probe' | 'battery-only';
export type AdvertisementState = 'idle' | 'visible' | 'not-seen' | 'unsupported';

export interface PenSnapshot {
  batteryLevel: number;
  isCharging: boolean;
  isConnected: boolean;
  hasBatterySample?: boolean;
  source: MonitorSource;
  strategy?: NativeStrategy;
  strategyReason?: string;
  advertisementState?: AdvertisementState;
  advertisementHint?: string;
  deviceId?: string;
  deviceName?: string;
  rssi?: number;
  lastUpdatedAt?: number;
}

export interface BleDiscoveredDevice {
  deviceId: string;
  deviceName: string;
  rssi?: number;
  rawDataHex: string;
  discoveredAt: number;
  autoMatched: boolean;
}

export interface GattServiceDigest {
  serviceUuid: string;
  characteristicUuids: string[];
}

export interface NativeMonitorCallbacks {
  onSnapshot: (snapshot: PenSnapshot) => void;
  onLog: (message: string) => void;
  onNativeUnavailable?: (reason: string) => void;
  onDeviceDiscovered?: (device: BleDiscoveredDevice) => void;
  onServicesResolved?: (services: GattServiceDigest[]) => void;
}

interface NativeMonitorOptions {
  preferredNames: string[];
  batteryServiceUuid: string;
  batteryLevelCharacteristicUuid: string;
  scanTimeoutMs: number;
  readIntervalMs: number;
  getBaselineLevel?: () => number;
}

export class PencilMonitorService {
  private callbacks?: NativeMonitorCallbacks;
  private options: NativeMonitorOptions = {
    preferredNames: ['m-pencil', 'huawei m-pencil', 'm pencil', 'mpencil'],
    batteryServiceUuid: '0000180f-0000-1000-8000-00805f9b34fb',
    batteryLevelCharacteristicUuid: '00002a19-0000-1000-8000-00805f9b34fb',
    scanTimeoutMs: 15000,
    readIntervalMs: 5000
  };

  private scanCallback?: (results: Array<bluetoothManager.ScanResult>) => void;
  private connectionCallback?: (state: bluetoothManager.BLEConnectChangedState) => void;
  private characteristicCallback?: (characteristic: bluetoothManager.BLECharacteristic) => void;
  private gattClient?: bluetoothManager.GattClientDevice;
  private batteryCharacteristic?: bluetoothManager.BLECharacteristic;

  private currentSnapshot?: PenSnapshot;
  private discoveredDevices: Map<string, BleDiscoveredDevice> = new Map();
  private scanTimeout: number = -1;
  private readTimer: number = -1;
  private isScanning: boolean = false;
  private reconnectAllowed: boolean = false;
  private autoConnectTriggered: boolean = false;
  private hasNativeBatterySample: boolean = false;
  private lastBatteryReadFailure: string = '';

  async startNativeMonitoring(
    callbacks: NativeMonitorCallbacks,
    options?: Partial<NativeMonitorOptions>
  ): Promise<boolean> {
    this.stopNativeMonitoring();
    this.callbacks = callbacks;
    this.options = {
      ...this.options,
      ...options
    };
    this.reconnectAllowed = true;
    this.autoConnectTriggered = false;

    if (!this.isBluetoothEnabled()) {
      callbacks.onLog('Bluetooth is off');
      if (callbacks.onNativeUnavailable) {
        callbacks.onNativeUnavailable('Bluetooth is off');
      }
      return false;
    }

    if (this.tryConnectMatchedPairedDevice()) {
      return true;
    }

    this.startScan();
    return true;
  }

  stopNativeMonitoring(): void {
    this.reconnectAllowed = false;
    this.stopScanOnly();
    this.stopReadLoop();
    this.cleanupGattClient();
    this.discoveredDevices.clear();
    this.autoConnectTriggered = false;
    this.currentSnapshot = undefined;
    this.batteryCharacteristic = undefined;
    this.hasNativeBatterySample = false;
    this.lastBatteryReadFailure = '';
  }

  connectToDiscoveredDevice(deviceId: string): boolean {
    if (!deviceId || deviceId.length === 0) {
      this.log('Manual connect failed: empty device id');
      return false;
    }

    const knownDevice = this.discoveredDevices.get(deviceId);
    const deviceName = knownDevice ? knownDevice.deviceName : this.safeGetRemoteDeviceName(deviceId);
    this.reconnectAllowed = true;
    this.connectToDevice(deviceId, deviceName, knownDevice ? knownDevice.rssi : undefined);
    return true;
  }

  nextMockSnapshot(current: PenSnapshot): PenSnapshot {
    if (!current.isConnected) {
      return {
        batteryLevel: current.batteryLevel,
        isCharging: current.isCharging,
        isConnected: current.isConnected,
        hasBatterySample: current.hasBatterySample,
        source: 'mock'
      };
    }

    let nextLevel = current.batteryLevel;
    if (current.isCharging && current.batteryLevel < 100) {
      nextLevel += 1;
    } else if (!current.isCharging && current.batteryLevel > 0) {
      nextLevel -= 1;
    }

    return {
      batteryLevel: Math.max(0, Math.min(100, nextLevel)),
      isCharging: current.isCharging,
      isConnected: current.isConnected,
      hasBatterySample: current.hasBatterySample,
      source: 'mock',
      deviceName: current.deviceName,
      deviceId: current.deviceId,
      lastUpdatedAt: Date.now()
    };
  }

  shouldTriggerAlert(
    previousLevel: number,
    nextSnapshot: PenSnapshot,
    isMonitoring: boolean,
    alertLimit: number,
    hasActiveAlert: boolean
  ): boolean {
    if (!isMonitoring || hasActiveAlert) {
      return false;
    }

    if (!nextSnapshot.isConnected || !nextSnapshot.isCharging) {
      return false;
    }

    return previousLevel < alertLimit && nextSnapshot.batteryLevel >= alertLimit;
  }

  private isBluetoothEnabled(): boolean {
    try {
      const state = bluetoothManager.getState();
      return state === bluetoothManager.BluetoothState.STATE_ON ||
        state === bluetoothManager.BluetoothState.STATE_BLE_ON;
    } catch (_) {
      return false;
    }
  }

  private tryConnectMatchedPairedDevice(): boolean {
    try {
      const pairedDevices = bluetoothManager.getPairedDevices();
      for (const deviceId of pairedDevices) {
        const deviceName = this.safeGetRemoteDeviceName(deviceId);
        if (this.isLikelyTargetDevice(deviceId, deviceName)) {
          this.log('Found paired candidate: ' + (deviceName || deviceId));
          this.connectToDevice(deviceId, deviceName);
          return true;
        }
      }
    } catch (error) {
      this.log('Read paired devices failed: ' + this.errorMessage(error));
    }
    return false;
  }

  private startScan(): void {
    this.stopScanOnly();
    this.discoveredDevices.clear();
    this.autoConnectTriggered = false;

    this.scanCallback = (results: Array<bluetoothManager.ScanResult>) => {
      this.handleScanResults(results);
    };

    try {
      const scanFilters = null as unknown as Array<bluetoothManager.ScanFilter>;
      bluetoothManager.BLE.on('BLEDeviceFind', this.scanCallback);
      bluetoothManager.BLE.startBLEScan(scanFilters, {
        dutyMode: bluetoothManager.ScanDuty.SCAN_MODE_LOW_LATENCY,
        matchMode: bluetoothManager.MatchMode.MATCH_MODE_AGGRESSIVE,
        interval: 0
      });
      this.isScanning = true;
      this.log('BLE scan started');

      this.scanTimeout = setTimeout(() => {
        this.stopScanOnly();
        if (this.discoveredDevices.size > 0) {
          this.log('BLE scan timeout, target device not identified');
          this.notifyUnavailable('Target device not identified');
        } else {
          this.log('BLE scan timeout, no nearby BLE device');
          this.notifyUnavailable('No nearby BLE device');
        }
      }, this.options.scanTimeoutMs);
    } catch (error) {
      this.log('BLE scan failed: ' + this.errorMessage(error));
      this.notifyUnavailable(this.mapScanFailureReason(error));
    }
  }

  private stopScanOnly(): void {
    if (this.scanTimeout !== -1) {
      clearTimeout(this.scanTimeout);
      this.scanTimeout = -1;
    }

    if (this.isScanning) {
      try {
        bluetoothManager.BLE.stopBLEScan();
      } catch (_) {
        // ignore
      }
      this.isScanning = false;
    }

    if (this.scanCallback) {
      try {
        bluetoothManager.BLE.off('BLEDeviceFind', this.scanCallback);
      } catch (_) {
        // ignore
      }
      this.scanCallback = undefined;
    }
  }

  private handleScanResults(results: Array<bluetoothManager.ScanResult>): void {
    for (const result of results) {
      if (!result.deviceId || result.deviceId.length === 0) {
        continue;
      }

      const deviceName = this.safeGetRemoteDeviceName(result.deviceId);
      const autoMatched = this.isLikelyTargetDevice(result.deviceId, deviceName);

      const discoveredDevice: BleDiscoveredDevice = {
        deviceId: result.deviceId,
        deviceName: deviceName || 'Unknown BLE device',
        rssi: result.rssi,
        rawDataHex: this.bufferToHex(result.data),
        discoveredAt: Date.now(),
        autoMatched
      };

      this.discoveredDevices.set(result.deviceId, discoveredDevice);
      if (this.callbacks && this.callbacks.onDeviceDiscovered) {
        this.callbacks.onDeviceDiscovered(discoveredDevice);
      }

      if (autoMatched && !this.autoConnectTriggered) {
        this.autoConnectTriggered = true;
        this.log('Auto connect candidate: ' + (deviceName || result.deviceId));
        this.connectToDevice(result.deviceId, deviceName, result.rssi);
        return;
      }
    }
  }

  private connectToDevice(deviceId: string, deviceName: string, rssi?: number): void {
    this.stopScanOnly();
    this.cleanupGattClient();

    try {
      this.gattClient = bluetoothManager.BLE.createGattClientDevice(deviceId);
      this.connectionCallback = (state: bluetoothManager.BLEConnectChangedState) => {
        this.handleConnectionStateChange(state);
      };
      this.characteristicCallback = (characteristic: bluetoothManager.BLECharacteristic) => {
        this.handleCharacteristicChanged(characteristic);
      };

      this.gattClient.on('BLEConnectionStateChange', this.connectionCallback);
      this.gattClient.on('BLECharacteristicChange', this.characteristicCallback);

      this.currentSnapshot = {
        batteryLevel: this.currentSnapshot ? this.currentSnapshot.batteryLevel : 0,
        isCharging: this.currentSnapshot ? this.currentSnapshot.isCharging : false,
        isConnected: false,
        hasBatterySample: false,
        source: 'ble',
        strategy: 'battery-only',
        strategyReason: 'Standard Battery Service only',
        advertisementState: 'unsupported',
        advertisementHint: 'Private charging channel is unavailable',
        deviceId,
        deviceName: deviceName || 'M-Pencil',
        rssi,
        lastUpdatedAt: Date.now()
      };
      this.emitSnapshot();
      this.log('Connecting ' + (deviceName || deviceId));
      this.gattClient.connect();
    } catch (error) {
      this.log('Create GATT client failed: ' + this.errorMessage(error));
      this.notifyUnavailable(this.mapGattFailureReason(error));
    }
  }

  private handleConnectionStateChange(state: bluetoothManager.BLEConnectChangedState): void {
    if (!this.currentSnapshot) {
      return;
    }

    if (state.state === bluetoothManager.ProfileConnectionState.STATE_CONNECTED) {
      this.currentSnapshot = {
        ...this.currentSnapshot,
        isConnected: true,
        hasBatterySample: false,
        lastUpdatedAt: Date.now()
      };
      this.emitSnapshot();
      this.log('Connected: ' + (this.currentSnapshot.deviceName || state.deviceId));
      setTimeout(() => {
        void this.bootstrapBatteryChannel();
      }, 250);
      return;
    }

    if (state.state === bluetoothManager.ProfileConnectionState.STATE_DISCONNECTED) {
      this.log('Disconnected: ' + (this.currentSnapshot.deviceName || state.deviceId));
      this.currentSnapshot = {
        ...this.currentSnapshot,
        isConnected: false,
        hasBatterySample: false,
        lastUpdatedAt: Date.now()
      };
      this.batteryCharacteristic = undefined;
      this.hasNativeBatterySample = false;
      this.emitSnapshot();
      this.stopReadLoop();
      if (this.reconnectAllowed) {
        this.startScan();
      }
    }
  }

  private async bootstrapBatteryChannel(): Promise<void> {
    if (!this.gattClient || !this.currentSnapshot) {
      return;
    }

    try {
      const services = await this.gattClient.getServices();
      const digests = this.toServiceDigest(services);
      if (this.callbacks && this.callbacks.onServicesResolved) {
        this.callbacks.onServicesResolved(digests);
      }
      this.log('Resolved services: ' + this.summarizeServices(digests));

      this.applyStrategy('battery-only', 'Threshold reminder mode');
      this.applyAdvertisementState('unsupported', 'No private vendor channel');

      const batteryCharacteristic = this.findBatteryCharacteristic(services);
      if (!batteryCharacteristic) {
        this.log('Battery service 180F/2A19 not found');
        this.notifyUnavailable('Battery service missing');
        return;
      }

      this.batteryCharacteristic = this.cloneCharacteristic(batteryCharacteristic);
      await this.readBatteryValue('Initial read');

      try {
        if (this.gattClient && this.batteryCharacteristic) {
          this.gattClient.setNotifyCharacteristicChanged(this.cloneCharacteristic(this.batteryCharacteristic), true);
          this.log('Battery notify enabled');
        }
      } catch (error) {
        this.log('Notify unavailable, fallback to polling: ' + this.errorMessage(error));
      }

      setTimeout(() => {
        void this.readBatteryValue('Quick recheck');
      }, 1500);

      this.startReadLoop();
    } catch (error) {
      this.log('Bootstrap failed: ' + this.errorMessage(error));
      this.notifyUnavailable(this.mapBootstrapFailureReason(error));
    }
  }

  private startReadLoop(): void {
    this.stopReadLoop();
    this.readTimer = setInterval(() => {
      void this.readBatteryValue('Poll battery');
    }, this.options.readIntervalMs);
  }

  private stopReadLoop(): void {
    if (this.readTimer !== -1) {
      clearInterval(this.readTimer);
      this.readTimer = -1;
    }
  }

  private async readBatteryValue(reason: string): Promise<void> {
    if (!this.gattClient || !this.batteryCharacteristic || !this.currentSnapshot || !this.currentSnapshot.isConnected) {
      return;
    }

    try {
      const characteristic = await this.gattClient.readCharacteristicValue(this.cloneCharacteristic(this.batteryCharacteristic));
      this.lastBatteryReadFailure = '';
      this.consumeBatteryLevel(characteristic.characteristicValue, reason);
      this.batteryCharacteristic = this.cloneCharacteristic(characteristic);
    } catch (error) {
      const message = this.errorMessage(error);
      if (message !== this.lastBatteryReadFailure) {
        this.lastBatteryReadFailure = message;
        this.log(reason + ' failed: ' + message);
        if (!this.hasNativeBatterySample && reason === 'Initial read') {
          const code = this.extractErrorCode(error);
          this.notifyUnavailable(code === 2900099 ? 'Battery read blocked' : 'Battery read failed');
        }
      }
    }
  }

  private handleCharacteristicChanged(characteristic: bluetoothManager.BLECharacteristic): void {
    if (!this.isBatteryCharacteristic(characteristic)) {
      return;
    }
    this.consumeBatteryLevel(characteristic.characteristicValue, 'Notify battery');
  }

  private consumeBatteryLevel(value: ArrayBuffer, sourceLabel: string): void {
    const bytes = new Uint8Array(value);
    if (bytes.length === 0 || !this.currentSnapshot) {
      return;
    }

    const previousLevel = this.currentSnapshot.batteryLevel;
    const nextLevel = Math.max(0, Math.min(100, bytes[0]));
    let nextCharging = this.currentSnapshot.isCharging;

    const referenceLevel = this.hasNativeBatterySample
      ? previousLevel
      : this.resolveBaselineLevel();
    if (referenceLevel >= 0) {
      if (nextLevel > referenceLevel) {
        nextCharging = true;
      } else if (nextLevel < referenceLevel) {
        nextCharging = false;
      }
    }

    this.currentSnapshot = {
      ...this.currentSnapshot,
      batteryLevel: nextLevel,
      isCharging: nextCharging,
      isConnected: true,
      hasBatterySample: true,
      source: 'ble',
      lastUpdatedAt: Date.now()
    };

    const firstSample = !this.hasNativeBatterySample;
    const levelChanged = nextLevel !== previousLevel;
    if (firstSample || levelChanged || sourceLabel !== 'Poll battery') {
      const name = this.currentSnapshot.deviceName || 'M-Pencil';
      this.log(sourceLabel + ' ' + name + ' battery ' + String(nextLevel) + '%');
    }
    this.emitSnapshot();
    this.hasNativeBatterySample = true;
  }

  private resolveBaselineLevel(): number {
    if (!this.options.getBaselineLevel) {
      return -1;
    }
    try {
      const value = this.options.getBaselineLevel();
      if (typeof value === 'number' && value > 0 && value <= 100) {
        return value;
      }
    } catch (_) {
      // ignore
    }
    return -1;
  }

  private findBatteryCharacteristic(services: Array<bluetoothManager.GattService>): bluetoothManager.BLECharacteristic | undefined {
    for (const service of services) {
      if (!this.isBatteryService(service.serviceUuid)) {
        continue;
      }
      for (const characteristic of service.characteristics) {
        if (this.isBatteryCharacteristic(characteristic)) {
          return characteristic;
        }
      }
    }
    return undefined;
  }

  private applyStrategy(strategy: NativeStrategy, reason: string): void {
    if (!this.currentSnapshot) {
      return;
    }
    this.currentSnapshot = {
      ...this.currentSnapshot,
      strategy,
      strategyReason: reason,
      lastUpdatedAt: Date.now()
    };
    this.emitSnapshot();
  }

  private applyAdvertisementState(state: AdvertisementState, hint: string): void {
    if (!this.currentSnapshot) {
      return;
    }
    this.currentSnapshot = {
      ...this.currentSnapshot,
      advertisementState: state,
      advertisementHint: hint,
      lastUpdatedAt: Date.now()
    };
    this.emitSnapshot();
  }

  private isBatteryService(serviceUuid: string): boolean {
    return this.normalizeUuid(serviceUuid) === this.normalizeUuid(this.options.batteryServiceUuid);
  }

  private isBatteryCharacteristic(characteristic: bluetoothManager.BLECharacteristic): boolean {
    return this.normalizeUuid(characteristic.characteristicUuid) ===
      this.normalizeUuid(this.options.batteryLevelCharacteristicUuid);
  }

  private cloneCharacteristic(characteristic: bluetoothManager.BLECharacteristic): bluetoothManager.BLECharacteristic {
    return {
      serviceUuid: characteristic.serviceUuid,
      characteristicUuid: characteristic.characteristicUuid,
      characteristicValue: characteristic.characteristicValue || new ArrayBuffer(0),
      descriptors: (characteristic.descriptors || []).map((descriptor: bluetoothManager.BLEDescriptor) => {
        return {
          serviceUuid: descriptor.serviceUuid,
          characteristicUuid: descriptor.characteristicUuid,
          descriptorUuid: descriptor.descriptorUuid,
          descriptorValue: descriptor.descriptorValue || new ArrayBuffer(0)
        };
      })
    };
  }

  private normalizeUuid(uuid: string): string {
    return uuid.toLowerCase().replace(/-/g, '');
  }

  private toServiceDigest(services: Array<bluetoothManager.GattService>): Array<GattServiceDigest> {
    return services.map((service: bluetoothManager.GattService) => {
      return {
        serviceUuid: service.serviceUuid,
        characteristicUuids: service.characteristics.map((characteristic: bluetoothManager.BLECharacteristic) => {
          return characteristic.characteristicUuid;
        })
      };
    });
  }

  private summarizeServices(services: Array<GattServiceDigest>): string {
    if (services.length === 0) {
      return 'No service';
    }
    return services.map((service: GattServiceDigest) => {
      return service.serviceUuid + '(' + String(service.characteristicUuids.length) + ')';
    }).join(' / ');
  }

  private isLikelyTargetDevice(deviceId: string, deviceName: string): boolean {
    if (deviceName.length > 0) {
      const lowerName = deviceName.toLowerCase();
      if (this.options.preferredNames.some((name: string) => lowerName.includes(name))) {
        return true;
      }
    }

    try {
      const deviceClass = bluetoothManager.getRemoteDeviceClass(deviceId);
      return deviceClass.majorMinorClass === bluetoothManager.MajorMinorClass.PERIPHERAL_DIGITAL_PEN;
    } catch (_) {
      return false;
    }
  }

  private safeGetRemoteDeviceName(deviceId: string): string {
    try {
      return bluetoothManager.getRemoteDeviceName(deviceId) || '';
    } catch (_) {
      return '';
    }
  }

  private bufferToHex(data: ArrayBuffer): string {
    const bytes = new Uint8Array(data);
    if (bytes.length === 0) {
      return '';
    }
    return Array.from(bytes).map((value: number) => value.toString(16).padStart(2, '0')).join(' ');
  }

  private cleanupGattClient(): void {
    if (!this.gattClient) {
      return;
    }

    if (this.connectionCallback) {
      try {
        this.gattClient.off('BLEConnectionStateChange', this.connectionCallback);
      } catch (_) {
        // ignore
      }
      this.connectionCallback = undefined;
    }

    if (this.characteristicCallback) {
      try {
        this.gattClient.off('BLECharacteristicChange', this.characteristicCallback);
      } catch (_) {
        // ignore
      }
      this.characteristicCallback = undefined;
    }

    try {
      this.gattClient.disconnect();
    } catch (_) {
      // ignore
    }

    try {
      this.gattClient.close();
    } catch (_) {
      // ignore
    }

    this.gattClient = undefined;
  }

  private extractErrorCode(error: unknown): number | undefined {
    if (typeof error === 'number') {
      return error;
    }
    if (!error || typeof error !== 'object') {
      return undefined;
    }
    const maybeCode = (error as Record<string, unknown>).code;
    if (typeof maybeCode === 'number') {
      return maybeCode;
    }
    return undefined;
  }

  private describeErrorCode(code: number | undefined): string {
    if (code === undefined) {
      return 'unknown-code';
    }
    if (code === 2900099) {
      return 'code=2900099 (operation not allowed for this characteristic)';
    }
    return 'code=' + String(code);
  }

  private errorMessage(error: unknown): string {
    const codeText = this.describeErrorCode(this.extractErrorCode(error));

    if (error === undefined || error === null) {
      return codeText;
    }

    if (typeof error === 'string') {
      return error.length > 0 ? codeText + ', ' + error : codeText;
    }

    if (typeof error === 'number') {
      return codeText;
    }

    if (typeof error === 'object') {
      const maybeMessage = (error as Record<string, unknown>).message;
      const maybeName = (error as Record<string, unknown>).name;
      if (typeof maybeMessage === 'string' && maybeMessage.length > 0) {
        if (typeof maybeName === 'string' && maybeName.length > 0) {
          return codeText + ', ' + maybeName + ': ' + maybeMessage;
        }
        return codeText + ', ' + maybeMessage;
      }
    }

    return codeText;
  }

  private emitSnapshot(): void {
    if (this.callbacks && this.callbacks.onSnapshot && this.currentSnapshot) {
      this.callbacks.onSnapshot(this.currentSnapshot);
    }
  }

  private log(message: string): void {
    if (this.callbacks && this.callbacks.onLog) {
      this.callbacks.onLog(message);
    }
  }

  private notifyUnavailable(reason: string): void {
    if (this.callbacks && this.callbacks.onNativeUnavailable) {
      this.callbacks.onNativeUnavailable(reason);
    }
  }

  private mapScanFailureReason(error: unknown): string {
    const code = this.extractErrorCode(error);
    if (code === 201) {
      return 'BLE scan permission denied';
    }
    if (code === 2900003) {
      return 'Bluetooth is off';
    }
    if (code === 2900001) {
      return 'BLE service stopped';
    }
    if (code === 801) {
      return 'BLE capability unsupported';
    }
    return 'BLE scan unavailable';
  }

  private mapGattFailureReason(error: unknown): string {
    const code = this.extractErrorCode(error);
    if (code === 201) {
      return 'GATT permission denied';
    }
    if (code === 2900003) {
      return 'Bluetooth is off';
    }
    if (code === 2900001) {
      return 'GATT service stopped';
    }
    if (code === 801) {
      return 'GATT unavailable';
    }
    return 'GATT unavailable';
  }

  private mapBootstrapFailureReason(error: unknown): string {
    const code = this.extractErrorCode(error);
    if (code === 201) {
      return 'GATT permission denied';
    }
    if (code === 2900003) {
      return 'Bluetooth is off';
    }
    if (code === 2900001) {
      return 'GATT service stopped';
    }
    return 'Bootstrap failed';
  }
}
