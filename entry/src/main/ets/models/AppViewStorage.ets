import { AppStatusModel, ReminderSettings } from './AppStatusModel';

type HomeHeroState =
  | 'monitor-off'
  | 'error'
  | 'no-device'
  | 'unstable'
  | 'stale'
  | 'connected-pending'
  | 'connected-idle'
  | 'connected-charging';

export const APP_VIEW_KEYS = {
  pageWidth: 'appView.pageWidth',
  pageHeight: 'appView.pageHeight',
  deviceName: 'appView.deviceName',
  heroStatusText: 'appView.heroStatusText',
  heroSyncText: 'appView.heroSyncText',
  batteryPercentText: 'appView.batteryPercentText',
  batteryLevel: 'appView.batteryLevel',
  batteryStateText: 'appView.batteryStateText',
  isConnected: 'appView.isConnected',
  canRetry: 'appView.canRetry',
  reminderThreshold: 'appView.reminderThreshold',
  repeatReminderEnabled: 'appView.repeatReminderEnabled',
  repeatReminderInterval: 'appView.repeatReminderInterval',
  backgroundMonitoringEnabled: 'appView.backgroundMonitoringEnabled',
  vibrationEnabled: 'appView.vibrationEnabled',
  backgroundMonitoringLimited: 'appView.backgroundMonitoringLimited',
  notificationPermissionGranted: 'appView.notificationPermissionGranted',
  appVersion: 'appView.appVersion',
  batteryHistoryVersion: 'appView.batteryHistoryVersion'
};

export function initializeAppViewStorage(): void {
  AppStorage.SetOrCreate(APP_VIEW_KEYS.pageWidth, 900);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.pageHeight, 1280);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.deviceName, 'M-Pencil');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.heroStatusText, '等待连接手写笔');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.heroSyncText, '等待连接手写笔');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.batteryPercentText, '--%');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.batteryLevel, 0);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.batteryStateText, '等待设备状态');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.isConnected, false);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.canRetry, true);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.reminderThreshold, 85);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.repeatReminderEnabled, false);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.repeatReminderInterval, 20);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.backgroundMonitoringEnabled, true);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.vibrationEnabled, false);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.backgroundMonitoringLimited, false);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.notificationPermissionGranted, false);
  AppStorage.SetOrCreate(APP_VIEW_KEYS.appVersion, '1.0.0');
  AppStorage.SetOrCreate(APP_VIEW_KEYS.batteryHistoryVersion, 0);
}

export function syncAppViewMetrics(pageWidth: number, pageHeight: number): void {
  AppStorage.Set(APP_VIEW_KEYS.pageWidth, pageWidth);
  AppStorage.Set(APP_VIEW_KEYS.pageHeight, pageHeight);
}

export function syncAppViewState(
  status: AppStatusModel,
  settings: ReminderSettings,
  appVersion: string
): void {
  const heroState = resolveHomeHeroState(status);

  AppStorage.Set(APP_VIEW_KEYS.deviceName, status.deviceName || 'M-Pencil');
  AppStorage.Set(APP_VIEW_KEYS.heroStatusText, buildHeroStatusText(status, heroState));
  AppStorage.Set(APP_VIEW_KEYS.heroSyncText, buildHeroSyncText(status, heroState));
  AppStorage.Set(APP_VIEW_KEYS.batteryPercentText, buildBatteryPercentText(status, heroState));
  AppStorage.Set(APP_VIEW_KEYS.batteryLevel, canDisplayBatteryLevel(heroState) ? Math.max(0, status.batteryLevel) : 0);
  AppStorage.Set(APP_VIEW_KEYS.batteryStateText, buildBatteryStateText(status, heroState));
  AppStorage.Set(APP_VIEW_KEYS.isConnected, heroState === 'connected-idle' || heroState === 'connected-charging');
  AppStorage.Set(APP_VIEW_KEYS.canRetry, heroState !== 'connected-idle' && heroState !== 'connected-charging');
  AppStorage.Set(APP_VIEW_KEYS.reminderThreshold, settings.reminderThreshold);
  AppStorage.Set(APP_VIEW_KEYS.repeatReminderEnabled, settings.repeatReminderEnabled);
  AppStorage.Set(APP_VIEW_KEYS.repeatReminderInterval, settings.repeatReminderInterval);
  AppStorage.Set(APP_VIEW_KEYS.backgroundMonitoringEnabled, settings.backgroundMonitoringEnabled);
  AppStorage.Set(APP_VIEW_KEYS.vibrationEnabled, settings.vibrationEnabled);
  AppStorage.Set(APP_VIEW_KEYS.backgroundMonitoringLimited, status.backgroundMonitoringLimited);
  AppStorage.Set(APP_VIEW_KEYS.notificationPermissionGranted, status.notificationPermissionGranted);
  AppStorage.Set(APP_VIEW_KEYS.appVersion, appVersion);
}

function resolveHomeHeroState(status: AppStatusModel): HomeHeroState {
  if (!status.monitoringEnabled) {
    return 'monitor-off';
  }
  if (status.connectionIssue.trim().length > 0) {
    return 'error';
  }
  if (status.staleData && hasRecordedBatterySample(status)) {
    return 'stale';
  }
  if (!status.isPencilDetected) {
    return 'no-device';
  }
  if (!status.isConnected) {
    return 'unstable';
  }
  if (!hasRecordedBatterySample(status)) {
    return 'connected-pending';
  }
  return status.isCharging ? 'connected-charging' : 'connected-idle';
}

function hasRecordedBatterySample(status: AppStatusModel): boolean {
  return status.hasBatterySample && status.lastSyncTime > 0 && status.batteryLevel >= 0;
}

function canDisplayBatteryLevel(heroState: HomeHeroState): boolean {
  return heroState === 'connected-idle' || heroState === 'connected-charging';
}

function buildHeroStatusText(status: AppStatusModel, heroState: HomeHeroState): string {
  switch (heroState) {
    case 'monitor-off':
      return '守护已关闭';
    case 'error':
      return '获取失败';
    case 'stale':
      return '状态已过期';
    case 'no-device':
      return status.isInitializing ? '查找中' : '未检测到';
    case 'unstable':
      return '连接不稳定';
    case 'connected-pending':
    case 'connected-charging':
    case 'connected-idle':
      return '手写笔已连接';
    default:
      return '等待连接';
  }
}

function buildHeroSyncText(status: AppStatusModel, heroState: HomeHeroState): string {
  switch (heroState) {
    case 'connected-charging':
    case 'connected-idle':
    case 'stale':
      return formatTime(status.lastSyncTime);
    default:
      return '--';
  }
}

function buildBatteryPercentText(status: AppStatusModel, heroState: HomeHeroState): string {
  if (!canDisplayBatteryLevel(heroState)) {
    return '--%';
  }
  return String(status.batteryLevel) + '%';
}

function buildBatteryStateText(status: AppStatusModel, heroState: HomeHeroState): string {
  switch (heroState) {
    case 'monitor-off':
      return '守护关闭';
    case 'error':
      return '获取失败';
    case 'stale':
      return '已过期';
    case 'no-device':
      return '未检测到';
    case 'unstable':
      return '连接不稳定';
    case 'connected-pending':
      return '读取中';
    case 'connected-charging':
      if (status.batteryLevel >= 100) {
        return '已充满';
      }
      return status.hasReachedThreshold ? '已达阈值' : '充电中';
    case 'connected-idle':
      if (status.batteryLevel >= 100) {
        return '已充满';
      }
      return '未在充电';
    default:
      return '等待';
  }
}

function formatTime(timestamp: number): string {
  if (timestamp <= 0) {
    return '--:--';
  }
  const date = new Date(timestamp);
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  return hh + ':' + mm;
}
