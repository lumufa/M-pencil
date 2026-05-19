export interface ReminderSettingsPatch {
  reminderThreshold?: number;
  repeatReminderEnabled?: boolean;
  repeatReminderInterval?: number;
  backgroundMonitoringEnabled?: boolean;
  vibrationEnabled?: boolean;
  onboardingCompleted?: boolean;
}

export interface AppUiBridgeHandlers {
  goHome?: () => void;
  openSettings?: () => void;
  openGuide?: () => void;
  retryMonitoring?: () => void;
  sendTestReminder?: () => void;
  openSystemSettings?: () => void;
  openFeedback?: () => void;
  openPrivacy?: () => void;
  updateReminderSettings?: (patch: ReminderSettingsPatch) => void;
  finishOnboarding?: () => void;
  clearBatteryHistory?: () => void;
}

export class AppUiBridge {
  private static handlers: AppUiBridgeHandlers = {};

  static setHandlers(handlers: AppUiBridgeHandlers): void {
    AppUiBridge.handlers = handlers;
  }

  static clearHandlers(): void {
    AppUiBridge.handlers = {};
  }

  static goHome(): void {
    AppUiBridge.handlers.goHome?.();
  }

  static openSettings(): void {
    AppUiBridge.handlers.openSettings?.();
  }

  static openGuide(): void {
    AppUiBridge.handlers.openGuide?.();
  }

  static retryMonitoring(): void {
    AppUiBridge.handlers.retryMonitoring?.();
  }

  static sendTestReminder(): void {
    AppUiBridge.handlers.sendTestReminder?.();
  }

  static openSystemSettings(): void {
    AppUiBridge.handlers.openSystemSettings?.();
  }

  static openFeedback(): void {
    AppUiBridge.handlers.openFeedback?.();
  }

  static openPrivacy(): void {
    AppUiBridge.handlers.openPrivacy?.();
  }

  static updateReminderSettings(patch: ReminderSettingsPatch): void {
    AppUiBridge.handlers.updateReminderSettings?.(patch);
  }

  static finishOnboarding(): void {
    AppUiBridge.handlers.finishOnboarding?.();
  }

  static clearBatteryHistory(): void {
    AppUiBridge.handlers.clearBatteryHistory?.();
  }
}
