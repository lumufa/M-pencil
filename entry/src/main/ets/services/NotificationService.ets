import { NativeReminderService, ReminderSendResult } from './NativeReminderService';

export { ReminderSendResult } from './NativeReminderService';

export class NotificationService {
  async isNotificationEnabled(): Promise<boolean> {
    return await NativeReminderService.isNotificationEnabled();
  }

  async requestNotificationPermission(): Promise<boolean> {
    return await NativeReminderService.requestNotificationPermission();
  }

  async sendThresholdReminder(level: number, vibrate: boolean = false): Promise<ReminderSendResult> {
    return await NativeReminderService.showThresholdReached(level, vibrate);
  }

  async sendNotificationCapabilityTest(): Promise<ReminderSendResult> {
    return await NativeReminderService.sendNotificationCapabilityTest();
  }

  async sendTestReminder(): Promise<ReminderSendResult> {
    return await this.sendNotificationCapabilityTest();
  }
}
