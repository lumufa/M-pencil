import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import bluetoothManager from '@ohos.bluetoothManager';
import bundleManager from '@ohos.bundle.bundleManager';
import geoLocationManager from '@ohos.geoLocationManager';
import hilog from '@ohos.hilog';

export type HarmonyPermission = string;
export type SwitchReadState = 'on' | 'off' | 'permission-missing' | 'service-stopped' | 'unsupported' | 'read-failed' | 'unknown';

export interface PermissionDefinition {
  permission: Permissions;
  label: string;
  blocking: boolean;
}

export interface PermissionStateItem {
  permission: HarmonyPermission;
  label: string;
  blocking: boolean;
  declared: boolean;
  requestAttempted: boolean;
  grantedByBundle?: boolean;
  grantedByToken: boolean;
  granted: boolean;
}

export interface PermissionRequestTrace {
  attempted: boolean;
  completed: boolean;
  requestedPermissions: HarmonyPermission[];
  grantedPermissions: HarmonyPermission[];
  deniedPermissions: HarmonyPermission[];
  errorText: string;
}

export interface SwitchTrace {
  state: SwitchReadState;
  detail: string;
}

export interface ScanPreparationState {
  contextReady: boolean;
  declarationChecked: boolean;
  declarationComplete: boolean;
  permissions: PermissionStateItem[];
  missingDeclarations: HarmonyPermission[];
  deniedScanPermissions: HarmonyPermission[];
  deniedReminderPermissions: HarmonyPermission[];
  bluetoothPermissionGranted: boolean;
  discoverPermissionGranted: boolean;
  locationPermissionGranted: boolean;
  approximateLocationPermissionGranted: boolean;
  vibrationPermissionGranted: boolean;
  bluetoothSwitch: SwitchTrace;
  locationSwitch: SwitchTrace;
  permissionRequest: PermissionRequestTrace;
  canStartScan: boolean;
  blockingReason:
    | 'none'
    | 'context-unavailable'
    | 'declaration-missing'
    | 'permission-missing'
    | 'bluetooth-off'
    | 'location-off';
}

const LOG_DOMAIN = 0x3201;
const LOG_TAG = 'MPencilPermission';

export class PermissionService {
  private readonly atManager = abilityAccessCtrl.createAtManager();
  private lastRequestTrace: PermissionRequestTrace = this.createIdleRequestTrace();

  readonly scanPermissionDefinitions: PermissionDefinition[] = [
    {
      permission: 'ohos.permission.USE_BLUETOOTH',
      label: '蓝牙使用',
      blocking: true
    },
    {
      permission: 'ohos.permission.DISCOVER_BLUETOOTH',
      label: '蓝牙扫描',
      blocking: true
    },
    {
      permission: 'ohos.permission.LOCATION',
      label: '精确位置',
      blocking: true
    },
    {
      permission: 'ohos.permission.APPROXIMATELY_LOCATION',
      label: '近似位置',
      blocking: true
    }
  ];

  readonly reminderPermissionDefinitions: PermissionDefinition[] = [
    {
      permission: 'ohos.permission.VIBRATE',
      label: '振动提醒',
      blocking: false
    }
  ];

  readonly allPermissionDefinitions: PermissionDefinition[] = [
    ...this.scanPermissionDefinitions,
    ...this.reminderPermissionDefinitions
  ];

  async requestScanPermissions(context?: common.UIAbilityContext): Promise<ScanPreparationState> {
    const current = await this.checkScanPreparation(context);
    if (!context) {
      return current;
    }

    if (current.missingDeclarations.length > 0 || current.deniedScanPermissions.length === 0) {
      return current;
    }

    this.lastRequestTrace = {
      attempted: true,
      completed: false,
      requestedPermissions: [...current.deniedScanPermissions],
      grantedPermissions: [],
      deniedPermissions: [],
      errorText: ''
    };

    try {
      const result = await this.atManager.requestPermissionsFromUser(context, current.deniedScanPermissions as Permissions[]);
      const grantedPermissions: HarmonyPermission[] = [];
      const deniedPermissions: HarmonyPermission[] = [];

      result.permissions.forEach((permission: string, index: number) => {
        if (result.authResults[index] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          grantedPermissions.push(permission);
        } else {
          deniedPermissions.push(permission);
        }
      });

      this.lastRequestTrace = {
        attempted: true,
        completed: true,
        requestedPermissions: [...result.permissions],
        grantedPermissions,
        deniedPermissions,
        errorText: ''
      };
      this.logInfo(
        '权限申请结果：同意=' + grantedPermissions.join('|') + '，拒绝=' + deniedPermissions.join('|')
      );
    } catch (error) {
      this.lastRequestTrace = {
        attempted: true,
        completed: false,
        requestedPermissions: [...current.deniedScanPermissions],
        grantedPermissions: [],
        deniedPermissions: [...current.deniedScanPermissions],
        errorText: this.errorMessage(error)
      };
      this.logWarn('Request permissions failed: ' + this.lastRequestTrace.errorText);
    }

    return await this.checkScanPreparation(context);
  }

  async checkScanPreparation(context?: common.UIAbilityContext): Promise<ScanPreparationState> {
    const bundleState = await this.readBundlePermissionState();
    if (!context) {
      return this.buildNoContextState(bundleState.declaredPermissions);
    }

    const tokenId = context.applicationInfo.accessTokenId;
    const permissions = this.allPermissionDefinitions.map((definition: PermissionDefinition) => {
      const declared = bundleState.declaredPermissions.has(definition.permission);
      const grantedByBundle = declared ? bundleState.declaredPermissions.get(definition.permission) : undefined;
      const grantedByToken = declared ? this.hasPermission(tokenId, definition.permission) : false;
      const granted = declared && (grantedByBundle === undefined ? grantedByToken : grantedByBundle);

      return {
        permission: definition.permission,
        label: definition.label,
        blocking: definition.blocking,
        declared,
        requestAttempted: this.lastRequestTrace.requestedPermissions.includes(definition.permission),
        grantedByBundle,
        grantedByToken,
        granted
      };
    });

    const missingDeclarations = permissions
      .filter((item: PermissionStateItem) => item.blocking && !item.declared)
      .map((item: PermissionStateItem) => item.permission);
    const deniedScanPermissions = permissions
      .filter((item: PermissionStateItem) => item.blocking && item.declared && !item.granted)
      .map((item: PermissionStateItem) => item.permission);
    const deniedReminderPermissions = permissions
      .filter((item: PermissionStateItem) => !item.blocking && item.declared && !item.granted)
      .map((item: PermissionStateItem) => item.permission);

    const bluetoothPermissionGranted = this.isPermissionGranted(permissions, 'ohos.permission.USE_BLUETOOTH');
    const discoverPermissionGranted = this.isPermissionGranted(permissions, 'ohos.permission.DISCOVER_BLUETOOTH');
    const locationPermissionGranted = this.isPermissionGranted(permissions, 'ohos.permission.LOCATION');
    const approximateLocationPermissionGranted = this.isPermissionGranted(
      permissions,
      'ohos.permission.APPROXIMATELY_LOCATION'
    );
    const vibrationPermissionGranted = this.isPermissionGranted(permissions, 'ohos.permission.VIBRATE');

    const bluetoothSwitch = this.readBluetoothSwitch(bluetoothPermissionGranted);
    const locationSwitch = this.readLocationSwitch();

    let blockingReason: ScanPreparationState['blockingReason'] = 'none';
    if (missingDeclarations.length > 0) {
      blockingReason = 'declaration-missing';
    } else if (deniedScanPermissions.length > 0) {
      blockingReason = 'permission-missing';
    } else if (bluetoothSwitch.state === 'off') {
      blockingReason = 'bluetooth-off';
    } else if (locationSwitch.state === 'off') {
      blockingReason = 'location-off';
    }

    return {
      contextReady: true,
      declarationChecked: bundleState.checked,
      declarationComplete: missingDeclarations.length === 0,
      permissions,
      missingDeclarations,
      deniedScanPermissions,
      deniedReminderPermissions,
      bluetoothPermissionGranted,
      discoverPermissionGranted,
      locationPermissionGranted,
      approximateLocationPermissionGranted,
      vibrationPermissionGranted,
      bluetoothSwitch,
      locationSwitch,
      permissionRequest: { ...this.lastRequestTrace },
      canStartScan: blockingReason === 'none',
      blockingReason
    };
  }

  shortPermissionName(permission: string): string {
    const match = this.allPermissionDefinitions.find((item: PermissionDefinition) => item.permission === permission);
    return match ? match.label : permission;
  }

  buildUserDebugText(state: ScanPreparationState): string {
    const declarationText = state.declarationChecked
      ? (state.declarationComplete ? '权限声明已配置' : '权限声明缺失')
      : '权限声明未校验';

    let requestText = '权限申请未发起';
    if (state.permissionRequest.attempted) {
      requestText = state.permissionRequest.completed
        ? '权限申请已发起'
        : '权限申请发起失败';
      if (state.permissionRequest.errorText.length > 0) {
        requestText += '（' + state.permissionRequest.errorText + '）';
      }
    }

    return declarationText +
      '，' + requestText +
      '，蓝牙使用权限' + this.permissionStatusText(state.permissions, 'ohos.permission.USE_BLUETOOTH') +
      '，蓝牙扫描权限' + this.permissionStatusText(state.permissions, 'ohos.permission.DISCOVER_BLUETOOTH') +
      '，精确位置权限' + this.permissionStatusText(state.permissions, 'ohos.permission.LOCATION') +
      '，近似位置权限' + this.permissionStatusText(state.permissions, 'ohos.permission.APPROXIMATELY_LOCATION') +
      '，蓝牙开关' + this.switchStatusText(state.bluetoothSwitch) +
      '，定位开关' + this.switchStatusText(state.locationSwitch);
  }

  private async readBundlePermissionState(): Promise<{
    checked: boolean;
    declaredPermissions: Map<HarmonyPermission, boolean>;
  }> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION
      );
      const declaredPermissions = new Map<HarmonyPermission, boolean>();
      bundleInfo.reqPermissionDetails.forEach((item, index: number) => {
        declaredPermissions.set(
          item.name,
          bundleInfo.permissionGrantStates[index] === bundleManager.PermissionGrantState.PERMISSION_GRANTED
        );
      });
      return {
        checked: true,
        declaredPermissions
      };
    } catch (error) {
      this.logWarn('Read bundle permissions failed: ' + this.errorMessage(error));
      return {
        checked: false,
        declaredPermissions: new Map()
      };
    }
  }

  private buildNoContextState(declaredPermissions: Map<HarmonyPermission, boolean>): ScanPreparationState {
    const permissions = this.allPermissionDefinitions.map((definition: PermissionDefinition) => {
      return {
        permission: definition.permission,
        label: definition.label,
        blocking: definition.blocking,
        declared: declaredPermissions.has(definition.permission),
        requestAttempted: false,
        grantedByBundle: declaredPermissions.get(definition.permission),
        grantedByToken: false,
        granted: false
      };
    });

    return {
      contextReady: false,
      declarationChecked: declaredPermissions.size > 0,
      declarationComplete: this.scanPermissionDefinitions.every((item: PermissionDefinition) => {
        return declaredPermissions.has(item.permission);
      }),
      permissions,
      missingDeclarations: permissions
        .filter((item: PermissionStateItem) => item.blocking && !item.declared)
        .map((item: PermissionStateItem) => item.permission),
      deniedScanPermissions: permissions
        .filter((item: PermissionStateItem) => item.blocking && item.declared && !item.granted)
        .map((item: PermissionStateItem) => item.permission),
      deniedReminderPermissions: permissions
        .filter((item: PermissionStateItem) => !item.blocking && item.declared && !item.granted)
        .map((item: PermissionStateItem) => item.permission),
      bluetoothPermissionGranted: false,
      discoverPermissionGranted: false,
      locationPermissionGranted: false,
      approximateLocationPermissionGranted: false,
      vibrationPermissionGranted: false,
      bluetoothSwitch: {
        state: 'unknown',
        detail: '应用上下文未就绪'
      },
      locationSwitch: {
        state: 'unknown',
        detail: '应用上下文未就绪'
      },
      permissionRequest: { ...this.lastRequestTrace },
      canStartScan: false,
      blockingReason: 'context-unavailable'
    };
  }

  private createIdleRequestTrace(): PermissionRequestTrace {
    return {
      attempted: false,
      completed: false,
      requestedPermissions: [],
      grantedPermissions: [],
      deniedPermissions: [],
      errorText: ''
    };
  }

  private hasPermission(tokenId: number, permission: Permissions): boolean {
    try {
      return this.atManager.verifyAccessTokenSync(tokenId, permission) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      this.logWarn('Verify permission failed for ' + permission + ': ' + this.errorMessage(error));
      return false;
    }
  }

  private isPermissionGranted(permissions: PermissionStateItem[], target: Permissions): boolean {
    const match = permissions.find((item: PermissionStateItem) => item.permission === target);
    return match ? match.granted : false;
  }

  private permissionStatusText(permissions: PermissionStateItem[], target: Permissions): string {
    const match = permissions.find((item: PermissionStateItem) => item.permission === target);
    if (!match) {
      return '未知';
    }
    if (!match.declared) {
      return '未声明';
    }
    if (match.granted) {
      return '已授予';
    }
    if (match.requestAttempted) {
      return '已申请但未授予';
    }
    return '未申请';
  }

  private readBluetoothSwitch(bluetoothPermissionGranted: boolean): SwitchTrace {
    if (!bluetoothPermissionGranted) {
      return {
        state: 'permission-missing',
        detail: '缺少蓝牙使用权限，无法读取'
      };
    }

    try {
      const state = bluetoothManager.getState();
      if (state === bluetoothManager.BluetoothState.STATE_ON ||
        state === bluetoothManager.BluetoothState.STATE_BLE_ON) {
        return {
          state: 'on',
          detail: '已开启'
        };
      }
      return {
        state: 'off',
        detail: '未开启'
      };
    } catch (error) {
      const code = this.extractErrorCode(error);
      if (code === 201) {
        return {
          state: 'permission-missing',
          detail: '系统判定蓝牙权限不足'
        };
      }
      if (code === 2900001) {
        return {
          state: 'service-stopped',
          detail: '蓝牙服务未启动'
        };
      }
      if (code === 801) {
        return {
          state: 'unsupported',
          detail: '当前设备不支持该读取方式'
        };
      }
      return {
        state: 'read-failed',
        detail: this.errorMessage(error)
      };
    }
  }

  private readLocationSwitch(): SwitchTrace {
    try {
      return geoLocationManager.isLocationEnabled()
        ? {
            state: 'on',
            detail: '已开启'
          }
        : {
            state: 'off',
            detail: '未开启'
          };
    } catch (error) {
      const code = this.extractErrorCode(error);
      if (code === 3301000) {
        return {
          state: 'service-stopped',
          detail: '定位服务不可用'
        };
      }
      if (code === 801) {
        return {
          state: 'unsupported',
          detail: '当前设备不支持该读取方式'
        };
      }
      return {
        state: 'read-failed',
        detail: this.errorMessage(error)
      };
    }
  }

  private switchStatusText(trace: SwitchTrace): string {
    if (trace.state === 'on') {
      return '已开启';
    }
    if (trace.state === 'off') {
      return '未开启';
    }
    if (trace.state === 'permission-missing') {
      return '未读取（权限不足）';
    }
    if (trace.state === 'service-stopped') {
      return '未读取（服务不可用）';
    }
    if (trace.state === 'unsupported') {
      return '未读取（设备不支持）';
    }
    if (trace.state === 'read-failed') {
      return '未读取（接口失败）';
    }
    return '未知';
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

  private errorMessage(error: unknown): string {
    if (error === undefined || error === null) {
      return 'unknown';
    }
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error === 'number') {
      return 'code=' + String(error);
    }
    if (typeof error === 'object') {
      const maybeCode = (error as Record<string, unknown>).code;
      const maybeMessage = (error as Record<string, unknown>).message;
      const codeText = typeof maybeCode === 'number' ? 'code=' + String(maybeCode) : 'code=unknown';
      if (typeof maybeMessage === 'string' && maybeMessage.length > 0) {
        return codeText + ', ' + maybeMessage;
      }
      return codeText;
    }
    return 'unknown';
  }

  private logInfo(message: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  private logWarn(message: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }
}
