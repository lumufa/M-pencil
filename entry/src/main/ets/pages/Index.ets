import display from '@ohos.display';
import promptAction from '@ohos.promptAction';
import Want from '@ohos.app.ability.Want';
import hilog from '@ohos.hilog';
import { FeedbackPage } from './FeedbackPage';
import { HomePage } from './HomePage';
import { OnboardingPage } from './OnboardingPage';
import { PrivacyPolicyPage } from './PrivacyPolicyPage';
import { SettingsPage } from './SettingsPage';
import { AppContextHolder } from '../services/AppContextHolder';
import { AppUiBridge, ReminderSettingsPatch } from '../services/AppUiBridge';
import { AppSettingsService } from '../services/AppSettingsService';
import { BatteryHistoryService } from '../services/BatteryHistoryService';
import { NotificationService, ReminderSendResult } from '../services/NotificationService';
import { PermissionService, ScanPreparationState } from '../services/PermissionService';
import { ReminderStrategy } from '../services/ReminderStrategy';
import {
  BleDiscoveredDevice,
  PenSnapshot,
  PencilMonitorService
} from '../services/PencilMonitorService';
import {
  AppStatusModel,
  buildStatusRecommendation,
  buildStatusSummary,
  createDefaultReminderSettings,
  createInitialAppStatus,
  ReminderSettings
} from '../models/AppStatusModel';
import {
  initializeAppViewStorage,
  syncAppViewMetrics,
  syncAppViewState
} from '../models/AppViewStorage';

type AppRoute = 'home' | 'settings' | 'onboarding' | 'feedback' | 'privacy';

const LOG_DOMAIN = 0x3202;
const LOG_TAG = 'MPencilHome';

@Entry
@Component
struct Index {
  @State private pageWidth: number = 900;
  @State private pageHeight: number = 1280;
  @State private route: AppRoute = 'home';
  @State private onboardingFromSettings: boolean = false;

  @State private settings: ReminderSettings = createDefaultReminderSettings();
  @State private status: AppStatusModel = createInitialAppStatus();
  @State private appVersion: string = '1.0.0';

  private readonly monitorService: PencilMonitorService = new PencilMonitorService();
  private readonly permissionService: PermissionService = new PermissionService();
  private readonly settingsService: AppSettingsService = new AppSettingsService();
  private readonly batteryHistoryService: BatteryHistoryService = BatteryHistoryService.instance();
  private readonly notificationService: NotificationService = new NotificationService();
  private readonly reminderStrategy: ReminderStrategy = new ReminderStrategy();
  private readonly preferredPencilNames: string[] = ['m-pencil', 'huawei m-pencil', 'm pencil', 'mpencil'];

  private staleCheckTimer: number = -1;
  private initializing: boolean = false;
  private permissionRequestStarted: boolean = false;
  private scanStarted: boolean = false;
  private nearbyDeviceSeen: boolean = false;
  private candidateDetected: boolean = false;
  private connectionStageEntered: boolean = false;
  private readStageEntered: boolean = false;

  aboutToAppear(): void {
    initializeAppViewStorage();
    this.syncPageMetrics();
    this.commitStatus(this.buildNextStatus({}));
    AppUiBridge.setHandlers({
      goHome: () => {
        this.route = 'home';
      },
      openSettings: () => {
        this.route = 'settings';
      },
      openGuide: () => {
        this.onboardingFromSettings = this.route === 'settings';
        this.route = 'onboarding';
      },
      retryMonitoring: () => {
        if (!this.settings.backgroundMonitoringEnabled) {
          this.showToast('请先在设置中开启后台守护。');
          return;
        }
        void this.initializeMonitoring(true);
      },
      sendTestReminder: () => {
        void this.sendTestReminder();
      },
      openSystemSettings: () => {
        void this.openSystemSettings();
      },
      openFeedback: () => {
        this.route = 'feedback';
      },
      openPrivacy: () => {
        this.route = 'privacy';
      },
      updateReminderSettings: (patch: ReminderSettingsPatch) => {
        void this.updateReminderSettings(patch);
      },
      finishOnboarding: () => {
        void this.finishOnboarding();
      },
      clearBatteryHistory: () => {
        this.batteryHistoryService.clear();
        this.showToast('电量历史已清除');
      }
    });
    void this.bootstrapApp();
  }

  aboutToDisappear(): void {
    AppUiBridge.clearHandlers();
    this.stopRuntime();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.route === 'home') {
        HomePage();
      } else if (this.route === 'settings') {
        SettingsPage();
      } else if (this.route === 'feedback') {
        FeedbackPage();
      } else if (this.route === 'privacy') {
        PrivacyPolicyPage();
      } else {
        OnboardingPage();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F0');
  }

  private async bootstrapApp(): Promise<void> {
    const context = AppContextHolder.get();
    this.settings = await this.settingsService.load(context);
    await this.batteryHistoryService.init(context);
    this.commitStatus(this.buildNextStatus({
      reminderThreshold: this.settings.reminderThreshold,
      repeatReminderEnabled: this.settings.repeatReminderEnabled,
      repeatReminderInterval: this.settings.repeatReminderInterval,
      monitoringEnabled: this.settings.backgroundMonitoringEnabled,
      connectionIssue: '',
      connectionStateText: this.settings.backgroundMonitoringEnabled ? '等待连接手写笔' : '后台守护已关闭',
      permissionStateText: '正在检查检测条件'
    }));

    this.route = this.settings.onboardingCompleted ? 'home' : 'onboarding';

    if (!this.settings.backgroundMonitoringEnabled) {
      return;
    }

    this.startStaleCheckLoop();
    await this.initializeMonitoring(false);
  }

  private stopRuntime(): void {
    this.monitorService.stopNativeMonitoring();
    this.reminderStrategy.resetCycle();
    if (this.staleCheckTimer !== -1) {
      clearInterval(this.staleCheckTimer);
      this.staleCheckTimer = -1;
    }
    this.initializing = false;
    this.resetMonitorFlags();
  }

  private async refreshPermissionState(): Promise<ScanPreparationState> {
    const context = AppContextHolder.get();
    this.permissionRequestStarted = true;
    const scanState = await this.permissionService.requestScanPermissions(context);
    const notificationEnabled = await this.notificationService.isNotificationEnabled();

    this.applyStatusPatch({
      notificationPermissionGranted: notificationEnabled,
      permissionStateText: this.permissionService.buildUserDebugText(scanState)
    });

    this.logInfo('检查检测条件：' + this.permissionService.buildUserDebugText(scanState));
    return scanState;
  }

  private async initializeMonitoring(forceRetry: boolean): Promise<void> {
    if (this.initializing || !this.settings.backgroundMonitoringEnabled) {
      return;
    }

    this.initializing = true;
    this.monitorService.stopNativeMonitoring();
    this.reminderStrategy.resetCycle();
    this.resetMonitorFlags();
    this.applyStatusPatch({
      isInitializing: true,
      monitoringEnabled: true,
      isPencilDetected: false,
      isConnected: false,
      isCharging: false,
      hasBatterySample: false,
      staleData: false,
      backgroundMonitoringLimited: false,
      lastSyncTime: 0,
      connectionIssue: '',
      connectionStateText: forceRetry ? '正在重新检查设备状态' : '正在检查检测条件',
      permissionStateText: '正在检查检测条件'
    });

    const scanState = await this.refreshPermissionState();
    if (!scanState.canStartScan) {
      this.initializing = false;
      this.applyReadinessFailure(scanState);
      return;
    }

    this.applyStatusPatch({
      connectionStateText: '正在扫描附近设备',
      permissionStateText: this.buildRuntimeDebugText()
    });

    const started = await this.monitorService.startNativeMonitoring({
      onSnapshot: (snapshot: PenSnapshot) => {
        this.handleMonitorSnapshot(snapshot);
      },
      onLog: (message: string) => {
        this.handleMonitorLog(message);
      },
      onNativeUnavailable: (reason: string) => {
        this.handleUnavailableReason(reason);
      },
      onDeviceDiscovered: (device: BleDiscoveredDevice) => {
        this.handleDiscoveredDevice(device);
      }
    }, {
      preferredNames: this.preferredPencilNames,
      getBaselineLevel: () => this.batteryHistoryService.getMinLevelWithin(30 * 60 * 1000)
    });

    if (!started && this.status.connectionIssue.length === 0) {
      this.applyStatusPatch({
        connectionStateText: '设备状态获取失败',
        connectionIssue: this.buildFailureDetail('蓝牙检测服务没有成功启动。')
      });
    }

    this.initializing = false;
    this.applyStatusPatch({ isInitializing: false });
  }

  private handleDiscoveredDevice(device: BleDiscoveredDevice): void {
    this.nearbyDeviceSeen = true;
    this.logInfo(
      '发现蓝牙设备：' + (device.deviceName || device.deviceId) +
      '，候选=' + (device.autoMatched ? '是' : '否')
    );

    if (!device.autoMatched) {
      this.applyStatusPatch({
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    this.candidateDetected = true;
    this.connectionStageEntered = true;
    this.applyStatusPatch({
      isPencilDetected: true,
      isConnected: false,
      hasBatterySample: false,
      staleData: false,
      deviceName: device.deviceName || this.status.deviceName || 'M-Pencil',
      connectionIssue: '',
      connectionStateText: '已发现候选设备，正在连接',
      permissionStateText: this.buildRuntimeDebugText()
    });
  }

  private handleMonitorSnapshot(snapshot: PenSnapshot): void {
    const previous = this.status;
    const hasBatterySample = snapshot.hasBatterySample === true;

    if (snapshot.isConnected) {
      this.connectionStageEntered = true;
    }
    if (hasBatterySample) {
      this.readStageEntered = true;
    }

    const nextStatus = this.buildNextStatus({
      isPencilDetected: true,
      isConnected: snapshot.isConnected,
      isCharging: snapshot.isConnected && hasBatterySample ? snapshot.isCharging : false,
      hasBatterySample,
      batteryLevel: hasBatterySample ? snapshot.batteryLevel : previous.batteryLevel,
      deviceName: snapshot.deviceName || previous.deviceName || 'M-Pencil',
      lastSyncTime: hasBatterySample ? (snapshot.lastUpdatedAt || Date.now()) : previous.lastSyncTime,
      staleData: false,
      connectionIssue: '',
      permissionStateText: this.buildRuntimeDebugText(),
      connectionStateText: !snapshot.isConnected
        ? '连接状态不稳定'
        : hasBatterySample
          ? (snapshot.isCharging ? '已连接，正在充电' : '已连接，未在充电')
          : '已连接，正在读取设备状态'
    });
    this.commitStatus(nextStatus);

    if (hasBatterySample) {
      this.batteryHistoryService.ingest(
        snapshot.batteryLevel,
        snapshot.isCharging,
        snapshot.lastUpdatedAt || Date.now()
      );
    }

    const decision = this.reminderStrategy.evaluate(previous, nextStatus);
    if (decision.shouldTrigger) {
      void this.triggerThresholdReminder(nextStatus.batteryLevel);
    }
  }

  private handleUnavailableReason(reason: string): void {
    this.logWarn('检测链路失败：' + reason);

    if (reason === 'Bluetooth is off') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '蓝牙未开启',
        connectionIssue: this.buildFailureDetail('系统蓝牙开关未开启，请开启后重新检测。')
      });
      return;
    }

    if (reason === 'No nearby BLE device') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '未发现附近设备',
        connectionIssue: this.buildFailureDetail('扫描已经启动，但附近没有发现可连接的手写笔设备。')
      });
      return;
    }

    if (reason === 'Target device not identified') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '未识别出手写笔',
        connectionIssue: this.buildFailureDetail('扫描已发现附近蓝牙设备，但没有识别出可作为手写笔的候选设备。')
      });
      return;
    }

    if (reason === 'BLE scan permission denied') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '蓝牙扫描被系统拒绝',
        connectionIssue: this.buildFailureDetail(
          '扫描启动时被系统拒绝，失败点不在首页蓝牙/定位开关判断，而在蓝牙扫描接口本身。'
        )
      });
      return;
    }

    if (reason === 'BLE service stopped') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '蓝牙服务不可用',
        connectionIssue: this.buildFailureDetail('蓝牙扫描服务当前不可用，应用无法开始检测。')
      });
      return;
    }

    if (reason === 'BLE capability unsupported') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '设备不支持当前扫描方式',
        connectionIssue: this.buildFailureDetail('当前系统没有向应用开放可用的蓝牙扫描能力。')
      });
      return;
    }

    if (reason === 'Battery service missing') {
      this.readStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: true,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '无法读取设备电量',
        connectionIssue: this.buildFailureDetail(
          '手写笔已连接，但系统没有向应用开放标准电量服务，无法读取真实电量。'
        )
      });
      return;
    }

    if (reason === 'Battery read blocked') {
      this.readStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: true,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '电量读取被系统拦截',
        connectionIssue: this.buildFailureDetail(
          '手写笔已连接，但电量读取被系统拦截，第三方应用拿不到真实状态。'
        )
      });
      return;
    }

    if (reason === 'Battery read failed') {
      this.readStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: true,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '读取设备状态失败',
        connectionIssue: this.buildFailureDetail('手写笔已连接，但暂时无法读取设备状态。')
      });
      return;
    }

    if (reason === 'GATT permission denied') {
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '连接设备被系统拒绝',
        connectionIssue: this.buildFailureDetail('候选设备已找到，但连接阶段被系统拒绝。')
      });
      return;
    }

    if (reason === 'GATT service stopped') {
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '连接服务不可用',
        connectionIssue: this.buildFailureDetail('连接阶段可用的蓝牙服务当前不可用。')
      });
      return;
    }

    if (reason === 'GATT unavailable' || reason === 'Bootstrap failed') {
      this.applyStatusPatch({
        isPencilDetected: this.candidateDetected,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '连接链路不可用',
        connectionIssue: this.buildFailureDetail('已进入连接链路，但系统没有返回可用的设备服务。')
      });
      return;
    }

    if (reason === 'BLE scan unavailable') {
      this.applyStatusPatch({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        connectionStateText: '蓝牙扫描启动失败',
        connectionIssue: this.buildFailureDetail('扫描没有成功启动，失败原因不是首页权限判断，而是蓝牙扫描接口返回失败。')
      });
      return;
    }

    this.applyStatusPatch({
      isPencilDetected: false,
      isConnected: false,
      isCharging: false,
      hasBatterySample: false,
      staleData: false,
      connectionStateText: '检测链路失败',
      connectionIssue: this.buildFailureDetail('设备状态获取失败，请重新检测后再试。')
    });
  }

  private async updateReminderSettings(patch: Partial<ReminderSettings>): Promise<void> {
    const context = AppContextHolder.get();
    const before = this.settings;
    this.settings = await this.settingsService.update(context, this.settings, patch);

    this.commitStatus(this.buildNextStatus({
      reminderThreshold: this.settings.reminderThreshold,
      repeatReminderEnabled: this.settings.repeatReminderEnabled,
      repeatReminderInterval: this.settings.repeatReminderInterval,
      monitoringEnabled: this.settings.backgroundMonitoringEnabled
    }));

    if (before.backgroundMonitoringEnabled && !this.settings.backgroundMonitoringEnabled) {
      this.stopRuntime();
      this.commitStatus(this.buildNextStatus({
        isPencilDetected: false,
        isConnected: false,
        isCharging: false,
        hasBatterySample: false,
        staleData: false,
        lastSyncTime: 0,
        connectionIssue: '',
        connectionStateText: '后台守护已关闭',
        permissionStateText: '后台守护已关闭'
      }));
      return;
    }

    if (!before.backgroundMonitoringEnabled && this.settings.backgroundMonitoringEnabled) {
      this.startStaleCheckLoop();
      await this.initializeMonitoring(true);
    }
  }

  private async finishOnboarding(): Promise<void> {
    if (!this.settings.onboardingCompleted) {
      const context = AppContextHolder.get();
      this.settings = await this.settingsService.update(context, this.settings, {
        onboardingCompleted: true
      });
    }
    this.route = this.onboardingFromSettings ? 'settings' : 'home';
    this.onboardingFromSettings = false;
    if (this.settings.backgroundMonitoringEnabled && !this.status.isConnected && !this.initializing) {
      await this.initializeMonitoring(true);
    }
  }

  private async sendTestReminder(): Promise<void> {
    const result = await this.notificationService.sendTestReminder();
    this.handleReminderResult(result);
  }

  private async triggerThresholdReminder(level: number): Promise<void> {
    const result = await this.notificationService.sendThresholdReminder(
      level,
      this.settings.vibrationEnabled
    );
    this.applyStatusPatch({
      notificationPermissionGranted: result.notificationEnabled,
      lastReminderTime: Date.now()
    });
    this.logInfo('阈值提醒结果：' + result.logMessage);
  }

  private handleReminderResult(result: ReminderSendResult): void {
    this.commitStatus(this.buildNextStatus({
      notificationPermissionGranted: result.notificationEnabled
    }));
    this.showToast(result.userMessage);
  }

  private async openSystemSettings(): Promise<void> {
    const context = AppContextHolder.get();
    if (!context) {
      this.showToast('暂时无法自动打开系统设置。');
      return;
    }

    try {
      const want: Want = {
        action: 'ohos.settings.APPLICATION_SETTINGS'
      };
      await context.startAbility(want);
    } catch (_) {
      this.showToast('请手动打开系统设置检查权限。');
    }
  }

  private startStaleCheckLoop(): void {
    if (this.staleCheckTimer !== -1) {
      clearInterval(this.staleCheckTimer);
      this.staleCheckTimer = -1;
    }
    this.staleCheckTimer = setInterval(() => {
      const stale = this.status.isConnected && this.status.hasBatterySample && this.status.lastSyncTime > 0 &&
        Date.now() - this.status.lastSyncTime > 90000;
      const limited = this.settings.backgroundMonitoringEnabled && stale;
      if (stale !== this.status.staleData || limited !== this.status.backgroundMonitoringLimited) {
        this.applyStatusPatch({
          staleData: stale,
          backgroundMonitoringLimited: limited
        });
      }
    }, 12000);
  }

  private applyStatusPatch(patch: Partial<AppStatusModel>): void {
    this.commitStatus(this.buildNextStatus(patch));
  }

  private buildNextStatus(patch: Partial<AppStatusModel>): AppStatusModel {
    const next: AppStatusModel = {
      ...this.status,
      ...patch
    };

    next.reminderThreshold = this.settings.reminderThreshold;
    next.repeatReminderEnabled = this.settings.repeatReminderEnabled;
    next.repeatReminderInterval = this.settings.repeatReminderInterval;
    next.monitoringEnabled = this.settings.backgroundMonitoringEnabled;

    if (!next.isConnected || !next.hasBatterySample) {
      next.isCharging = false;
    }

    const inferredStale = next.isConnected && next.hasBatterySample && next.lastSyncTime > 0 &&
      Date.now() - next.lastSyncTime > 90000;
    if (patch.staleData === undefined) {
      next.staleData = inferredStale;
    }
    if (patch.backgroundMonitoringLimited === undefined) {
      next.backgroundMonitoringLimited = next.monitoringEnabled && next.staleData;
    }

    next.hasReachedThreshold = next.isConnected && next.hasBatterySample &&
      !next.staleData && next.batteryLevel >= next.reminderThreshold;

    if (!next.deviceName || next.deviceName.length === 0) {
      next.deviceName = 'M-Pencil';
    }

    next.statusSummary = buildStatusSummary(next);
    next.statusRecommendation = buildStatusRecommendation(next);
    return next;
  }

  private commitStatus(next: AppStatusModel): void {
    this.status = next;
    syncAppViewState(next, this.settings, this.appVersion);
  }

  private applyReadinessFailure(scanState: ScanPreparationState): void {
    let connectionIssue = '当前无法开始检测。';
    let connectionStateText = '检测准备失败';
    if (scanState.blockingReason === 'context-unavailable') {
      connectionIssue = '应用上下文尚未就绪，检测服务还没有准备完成。';
      connectionStateText = '等待应用就绪';
    } else if (scanState.blockingReason === 'declaration-missing') {
      const missingLabels = scanState.missingDeclarations
        .map((permission: string) => this.permissionService.shortPermissionName(permission))
        .join('、');
      connectionIssue = '安装包里缺少检测所需权限声明：' + missingLabels + '。';
      connectionStateText = '权限声明缺失';
    } else if (scanState.blockingReason === 'permission-missing') {
      const deniedLabels = scanState.deniedScanPermissions
        .map((permission: string) => this.permissionService.shortPermissionName(permission))
        .join('、');
      connectionIssue = '检测权限尚未授予：' + deniedLabels + '。';
      if (scanState.permissionRequest.attempted) {
        connectionIssue += scanState.permissionRequest.completed
          ? ' 已发起权限申请，但系统仍未授予。'
          : ' 权限申请没有成功弹出。';
      } else if (!this.permissionRequestStarted) {
        connectionIssue += ' 当前还没有发起权限申请。';
      }
      connectionStateText = '检测权限未开启';
    } else if (scanState.blockingReason === 'bluetooth-off') {
      connectionIssue = '系统蓝牙开关未开启，当前无法开始检测。';
      connectionStateText = '蓝牙未开启';
    } else if (scanState.blockingReason === 'location-off') {
      connectionIssue = '系统定位开关未开启，当前无法开始检测。';
      connectionStateText = '定位未开启';
    }

    this.applyStatusPatch({
      isInitializing: false,
      connectionStateText,
      connectionIssue: connectionIssue + ' ' + this.permissionService.buildUserDebugText(scanState),
      permissionStateText: this.permissionService.buildUserDebugText(scanState)
    });
  }

  private handleMonitorLog(message: string): void {
    this.logInfo('检测日志：' + message);

    if (message.includes('BLE scan started')) {
      this.scanStarted = true;
      this.applyStatusPatch({
        connectionStateText: '正在扫描附近设备',
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    if (message.includes('Found paired candidate') || message.includes('Auto connect candidate')) {
      this.candidateDetected = true;
      this.connectionStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        connectionStateText: '已发现候选设备，正在连接',
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    if (message.startsWith('Connecting ')) {
      this.connectionStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        connectionStateText: '已进入连接阶段',
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    if (message.startsWith('Connected:')) {
      this.connectionStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: true,
        connectionStateText: '已连接，正在解析设备服务',
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    if (message.startsWith('Resolved services:')) {
      this.readStageEntered = true;
      this.applyStatusPatch({
        isPencilDetected: true,
        isConnected: true,
        connectionStateText: '已连接，正在读取设备状态',
        permissionStateText: this.buildRuntimeDebugText()
      });
      return;
    }

    if (message.startsWith('Initial read') || message.startsWith('Notify battery') || message.startsWith('Poll battery')) {
      this.readStageEntered = true;
      this.applyStatusPatch({
        permissionStateText: this.buildRuntimeDebugText()
      });
    }
  }

  private buildRuntimeDebugText(): string {
    return '蓝牙扫描' + this.stageText(this.scanStarted) +
      '，附近设备' + this.stageText(this.nearbyDeviceSeen) +
      '，候选设备' + this.stageText(this.candidateDetected) +
      '，连接阶段' + this.stageText(this.connectionStageEntered) +
      '，读取阶段' + this.stageText(this.readStageEntered);
  }

  private buildFailureDetail(message: string): string {
    return message + ' 调试：' + this.buildRuntimeDebugText();
  }

  private resetMonitorFlags(): void {
    this.permissionRequestStarted = false;
    this.scanStarted = false;
    this.nearbyDeviceSeen = false;
    this.candidateDetected = false;
    this.connectionStageEntered = false;
    this.readStageEntered = false;
  }

  private stageText(value: boolean): string {
    return value ? '已进入' : '未进入';
  }

  private showToast(message: string): void {
    promptAction.showToast({
      message,
      duration: 1800
    });
  }

  private syncPageMetrics(): void {
    try {
      const screen = display.getDefaultDisplaySync();
      const density = screen.densityDPI > 0 ? screen.densityDPI : 160;
      this.pageWidth = Math.max(320, Math.round(screen.width * 160 / density));
      this.pageHeight = Math.max(480, Math.round(screen.height * 160 / density));
      syncAppViewMetrics(this.pageWidth, this.pageHeight);
    } catch (_) {
      return;
    }
  }

  private logInfo(message: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }

  private logWarn(message: string): void {
    hilog.warn(LOG_DOMAIN, LOG_TAG, '%{public}s', message);
  }
}
