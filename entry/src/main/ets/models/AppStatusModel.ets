export type StatusTone = 'neutral' | 'success' | 'warning';

export interface ReminderSettings {
  reminderThreshold: number;
  repeatReminderEnabled: boolean;
  repeatReminderInterval: number;
  backgroundMonitoringEnabled: boolean;
  vibrationEnabled: boolean;
  onboardingCompleted: boolean;
}

export interface StatusNotice {
  id: string;
  tone: StatusTone;
  title: string;
  description: string;
  actionLabel?: string;
  actionKey?: 'retry' | 'settings' | 'guide' | 'permission' | 'none';
}

export interface StatusFact {
  id: string;
  label: string;
  value: string;
  hint: string;
  tone: StatusTone;
}

export class MonitorLogItem {
  id: string;
  time: string;
  event: string;

  constructor(time: string, event: string) {
    this.id = String(Date.now()) + '-' + String(Math.random());
    this.time = time;
    this.event = event;
  }
}

export interface AppStatusModel {
  isPencilDetected: boolean;
  isConnected: boolean;
  isCharging: boolean;
  hasBatterySample: boolean;
  batteryLevel: number;
  reminderThreshold: number;
  hasReachedThreshold: boolean;
  notificationPermissionGranted: boolean;
  backgroundMonitoringLimited: boolean;
  lastSyncTime: number;
  lastReminderTime: number;
  repeatReminderEnabled: boolean;
  repeatReminderInterval: number;
  monitoringEnabled: boolean;
  isInitializing: boolean;
  isMockMode: boolean;
  deviceName: string;
  connectionStateText: string;
  permissionStateText: string;
  statusSummary: string;
  statusRecommendation: string;
  staleData: boolean;
  connectionIssue: string;
  supportsSystemSettingsLink: boolean;
}

export function createDefaultReminderSettings(): ReminderSettings {
  return {
    reminderThreshold: 85,
    repeatReminderEnabled: false,
    repeatReminderInterval: 20,
    backgroundMonitoringEnabled: true,
    vibrationEnabled: false,
    onboardingCompleted: false
  };
}

export function createInitialAppStatus(): AppStatusModel {
  return {
    isPencilDetected: false,
    isConnected: false,
    isCharging: false,
    hasBatterySample: false,
    batteryLevel: 0,
    reminderThreshold: 85,
    hasReachedThreshold: false,
    notificationPermissionGranted: false,
    backgroundMonitoringLimited: false,
    lastSyncTime: 0,
    lastReminderTime: 0,
    repeatReminderEnabled: false,
    repeatReminderInterval: 20,
    monitoringEnabled: true,
    isInitializing: false,
    isMockMode: false,
    deviceName: 'M-Pencil',
    connectionStateText: '等待连接手写笔',
    permissionStateText: '正在检查权限',
    statusSummary: '等待设备状态',
    statusRecommendation: '请将手写笔吸附到平板侧边后重试。',
    staleData: false,
    connectionIssue: '',
    supportsSystemSettingsLink: false
  };
}

export function buildStatusFacts(status: AppStatusModel): StatusFact[] {
  return [
    {
      id: 'pencil',
      label: '手写笔',
      value: status.isPencilDetected ? '已检测到' : '未检测到',
      hint: status.isPencilDetected ? status.deviceName : '请吸附到平板侧边',
      tone: status.isPencilDetected ? 'success' : 'warning'
    },
    {
      id: 'connection',
      label: '连接状态',
      value: status.isConnected ? '已连接' : '未连接',
      hint: status.isConnected ? '设备状态可刷新' : '可尝试重新检测',
      tone: status.isConnected ? 'success' : 'warning'
    },
    {
      id: 'threshold',
      label: '提醒阈值',
      value: String(status.reminderThreshold) + '%',
      hint: status.hasReachedThreshold ? '当前电量已达到提醒阈值' : '建议设置在 80% 到 85%',
      tone: status.hasReachedThreshold ? 'warning' : 'neutral'
    },
    {
      id: 'guard',
      label: '后台守护',
      value: status.monitoringEnabled ? '已开启' : '已关闭',
      hint: status.backgroundMonitoringLimited ? '后台刷新可能受限' : '建议保持开启',
      tone: status.monitoringEnabled ? 'success' : 'warning'
    }
  ];
}

export function buildStatusNotices(status: AppStatusModel): StatusNotice[] {
  const notices: StatusNotice[] = [];

  if (!status.notificationPermissionGranted) {
    notices.push({
      id: 'notification',
      tone: 'warning',
      title: '通知权限未开启',
      description: '建议开启通知权限，避免错过提醒。',
      actionLabel: '打开设置',
      actionKey: 'settings'
    });
  }

  if (status.backgroundMonitoringLimited) {
    notices.push({
      id: 'background',
      tone: 'neutral',
      title: '后台监测可能受限',
      description: '系统限制可能导致提醒或状态刷新延后。',
      actionLabel: '查看说明',
      actionKey: 'guide'
    });
  }

  if (status.connectionIssue.length > 0) {
    notices.unshift({
      id: 'connection-issue',
      tone: 'warning',
      title: '设备状态获取失败',
      description: status.connectionIssue,
      actionLabel: '重新检测',
      actionKey: 'retry'
    });
    return notices.slice(0, 3);
  }

  if (!status.isPencilDetected) {
    notices.unshift({
      id: 'not-detected',
      tone: 'warning',
      title: '未检测到手写笔',
      description: '请将手写笔吸附到平板侧边后重试。',
      actionLabel: '重新检测',
      actionKey: 'retry'
    });
    return notices.slice(0, 3);
  }

  if (!status.isConnected) {
    notices.unshift({
      id: 'disconnected',
      tone: 'warning',
      title: '连接状态不稳定',
      description: '已检测到手写笔，但还没有建立稳定连接。',
      actionLabel: '重新检测',
      actionKey: 'retry'
    });
    return notices.slice(0, 3);
  }

  if (status.staleData) {
    notices.unshift({
      id: 'stale',
      tone: 'warning',
      title: '设备状态长时间未刷新',
      description: '请重新吸附手写笔，确认电量状态仍然有效。',
      actionLabel: '重新检测',
      actionKey: 'retry'
    });
    return notices.slice(0, 3);
  }

  if (!status.hasBatterySample) {
    notices.unshift({
      id: 'pending-sample',
      tone: 'neutral',
      title: '正在获取设备状态',
      description: '已连接手写笔，正在读取电量信息。',
      actionLabel: '打开设置',
      actionKey: 'settings'
    });
    return notices.slice(0, 3);
  }

  if (status.hasReachedThreshold) {
    notices.unshift({
      id: 'threshold-reached',
      tone: 'warning',
      title: '已达到 ' + String(status.reminderThreshold) + '% 提醒阈值',
      description: '请及时手动取下手写笔，避免继续充电。',
      actionLabel: '发送测试提醒',
      actionKey: 'permission'
    });
    return notices.slice(0, 3);
  }

  if (status.isCharging) {
    notices.unshift({
      id: 'charging',
      tone: 'success',
      title: '已连接，正在充电',
      description: '到达提醒阈值后，应用会提醒你取下手写笔。',
      actionLabel: '提醒设置',
      actionKey: 'settings'
    });
  } else {
    notices.unshift({
      id: 'connected-idle',
      tone: 'neutral',
      title: '已连接，当前未在充电',
      description: '下一次吸附充电时，应用会继续监测。',
      actionLabel: '查看说明',
      actionKey: 'guide'
    });
  }

  return notices.slice(0, 3);
}

export function buildStatusSummary(status: AppStatusModel): string {
  if (!status.monitoringEnabled) {
    return '后台守护已关闭。';
  }
  if (status.connectionIssue.length > 0) {
    return '设备状态获取失败。';
  }
  if (status.staleData) {
    return '设备状态长时间未刷新。';
  }
  if (!status.isPencilDetected) {
    return '未检测到手写笔。';
  }
  if (!status.isConnected) {
    return '已检测到手写笔，但连接还不稳定。';
  }
  if (!status.hasBatterySample) {
    return '已连接，正在等待设备状态。';
  }
  if (status.hasReachedThreshold) {
    return '电量已达到提醒阈值。';
  }
  return status.isCharging ? '已连接，正在充电。' : '已连接，当前未在充电。';
}

export function buildStatusRecommendation(status: AppStatusModel): string {
  if (!status.monitoringEnabled) {
    return '请前往设置开启后台守护。';
  }
  if (status.connectionIssue.length > 0) {
    if (status.connectionIssue.includes('没有向应用开放标准电量服务') ||
      status.connectionIssue.includes('电量读取被系统拦截') ||
      status.connectionIssue.includes('没有向应用暴露可识别的 M-Pencil 标识')) {
      return '当前实现只能依赖系统暴露的蓝牙设备与标准电量服务；如果系统不开放，第三方应用就拿不到真实状态。';
    }
    return '请检查蓝牙和设备吸附状态后再试。';
  }
  if (!status.isPencilDetected) {
    return '请将手写笔吸附到平板侧边。';
  }
  if (!status.notificationPermissionGranted) {
    return '建议开启通知权限，避免错过提醒。';
  }
  if (status.backgroundMonitoringLimited) {
    return '系统可能限制后台刷新，建议定时打开应用查看状态。';
  }
  if (status.staleData) {
    return '请重新连接手写笔，让状态重新刷新。';
  }
  if (!status.isConnected) {
    return '请保持手写笔靠近设备，等待连接稳定。';
  }
  if (!status.hasBatterySample) {
    return '已连接，正在读取设备电量信息。';
  }
  if (status.hasReachedThreshold) {
    return '达到提醒后请手动取下手写笔。';
  }
  return status.isCharging
    ? '当前正在充电，达到阈值时会提醒你取下手写笔。'
    : '当前未在充电，下一次吸附时会继续监测。';
}
