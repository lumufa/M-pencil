import notificationManager from '@ohos.notificationManager';
import vibrator from '@ohos.vibrator';

export interface ReminderSendResult {
  state: string;
  success: boolean;
  notificationEnabled: boolean;
  notificationSent: boolean;
  vibrationMayBeLimited: boolean;
  message: string;
  userMessage: string;
  detailMessage: string;
  logMessage: string;
  errorCode?: number;
}

interface ReminderPayload {
  id: number;
  title: string;
  text: string;
  additionalText: string;
  logPrefix: string;
}

interface BusinessErrorLike {
  code?: number;
}

const REMINDER_STATE_SENT: string = 'sent';
const REMINDER_STATE_SENT_WITH_LIMITATION: string = 'sent_with_limitation';
const REMINDER_STATE_PERMISSION_MISSING: string = 'permission_missing';
const REMINDER_STATE_FAILED: string = 'failed';
const REMINDER_STATE_UNCERTAIN: string = 'uncertain';

export class NativeReminderService {
  private static readonly SLOT_TYPE = notificationManager.SlotType.SERVICE_INFORMATION;
  private static readonly TEST_NOTIFICATION_ID: number = 31001;
  private static readonly THRESHOLD_NOTIFICATION_ID: number = 31002;
  private static slotPrepared: boolean = false;

  static async prepare(): Promise<void> {
    await NativeReminderService.ensureNotificationSlot();
  }

  static async isNotificationEnabled(): Promise<boolean> {
    try {
      await NativeReminderService.ensureNotificationSlot();
      const slot = await notificationManager.getSlot(NativeReminderService.SLOT_TYPE);
      if (slot.enabled === false) {
        return false;
      }
      if (slot.level === notificationManager.SlotLevel.LEVEL_NONE) {
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  static async requestNotificationPermission(): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification();
    } catch (_) {
      return await NativeReminderService.isNotificationEnabled();
    }
    return await NativeReminderService.isNotificationEnabled();
  }

  static async showThresholdReached(level: number, vibrate: boolean = false): Promise<ReminderSendResult> {
    return await NativeReminderService.sendReminder({
      id: NativeReminderService.THRESHOLD_NOTIFICATION_ID,
      title: '\u624b\u5199\u7b14\u5145\u7535\u63d0\u9192',
      text: '\u624b\u5199\u7b14\u7535\u91cf\u5df2\u8fbe\u5230 ' + String(level) +
        '%\uff0c\u8bf7\u53ca\u65f6\u53d6\u4e0b\u624b\u5199\u7b14\uff0c\u907f\u514d\u7ee7\u7eed\u5438\u9644\u5145\u7535\u3002',
      additionalText: '\u6b63\u5f0f\u9608\u503c\u63d0\u9192',
      logPrefix: '\u9608\u503c\u63d0\u9192'
    }, vibrate);
  }

  static async sendNotificationCapabilityTest(): Promise<ReminderSendResult> {
    return await NativeReminderService.sendReminder({
      id: NativeReminderService.TEST_NOTIFICATION_ID,
      title: '\u6d4b\u8bd5\u63d0\u9192',
      text: '\u4ec5\u7528\u4e8e\u9a8c\u8bc1\u901a\u77e5\u80fd\u529b\uff0c\u4e0d\u4ee3\u8868\u5df2\u89e6\u53d1' +
        '\u6b63\u5f0f\u9608\u503c\u63d0\u9192\u3002',
      additionalText: '\u8bf7\u67e5\u770b\u7cfb\u7edf\u901a\u77e5\u680f',
      logPrefix: '\u6d4b\u8bd5\u63d0\u9192'
    });
  }

  static async sendTestReminder(): Promise<ReminderSendResult> {
    return await NativeReminderService.sendNotificationCapabilityTest();
  }

  private static async sendReminder(
    payload: ReminderPayload,
    vibrate: boolean = false
  ): Promise<ReminderSendResult> {
    const notificationEnabled = await NativeReminderService.isNotificationEnabled();
    if (!notificationEnabled) {
      return NativeReminderService.buildPermissionMissingResult(payload.logPrefix);
    }

    let slotVibrationEnabled: boolean | undefined = undefined;
    try {
      const slot = await notificationManager.getSlot(NativeReminderService.SLOT_TYPE);
      slotVibrationEnabled = slot.vibrationEnabled;
    } catch (_) {
      slotVibrationEnabled = undefined;
    }

    try {
      await NativeReminderService.ensureNotificationSlot();
      await notificationManager.publish({
        id: payload.id,
        slotType: NativeReminderService.SLOT_TYPE,
        deliveryTime: Date.now(),
        tapDismissed: true,
        isAlertOnce: false,
        content: {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: payload.title,
            text: payload.text,
            additionalText: payload.additionalText
          }
        }
      });
      if (vibrate) {
        await NativeReminderService.triggerVibration();
      }
      return NativeReminderService.buildSuccessResult(payload.logPrefix, slotVibrationEnabled);
    } catch (error) {
      return NativeReminderService.buildFailureResult(
        payload.logPrefix,
        error as BusinessErrorLike
      );
    }
  }

  private static async triggerVibration(): Promise<void> {
    try {
      await vibrator.startVibration(
        { type: 'time', duration: 500 },
        { usage: 'notification' }
      );
    } catch (_) {
      // Vibration is best-effort; ignore failures so notification flow is not blocked.
    }
  }

  private static async ensureNotificationSlot(): Promise<void> {
    if (NativeReminderService.slotPrepared) {
      return;
    }
    try {
      await notificationManager.addSlot(NativeReminderService.SLOT_TYPE);
    } catch (_) {
      // Slot may already exist or the platform may manage the slot automatically.
    }
    NativeReminderService.slotPrepared = true;
  }

  private static buildSuccessResult(
    logPrefix: string,
    slotVibrationEnabled?: boolean
  ): ReminderSendResult {
    if (slotVibrationEnabled === false) {
      const message = '\u901a\u77e5\u5df2\u53d1\u9001\uff0c\u632f\u52a8\u53ef\u80fd\u53d7' +
        '\u7cfb\u7edf\u9759\u97f3\u3001\u52ff\u6270\u6216\u901a\u77e5\u8bbe\u7f6e\u5f71\u54cd';
      return {
        state: REMINDER_STATE_SENT_WITH_LIMITATION,
        success: true,
        notificationEnabled: true,
        notificationSent: true,
        vibrationMayBeLimited: true,
        message: message,
        userMessage: message,
        detailMessage: '\u901a\u77e5\u5df2\u6210\u529f\u53d1\u9001\uff0c\u4f46\u5f53\u524d\u901a\u77e5' +
          '\u632f\u52a8\u5f00\u5173\u672a\u5f00\u542f\u3002',
        logMessage: logPrefix + '\u5df2\u53d1\u9001\uff0c\u4f46\u632f\u52a8\u53ef\u80fd\u53d7' +
          '\u7cfb\u7edf\u9650\u5236\u5f71\u54cd'
      };
    }

    if (slotVibrationEnabled === undefined) {
      const message = logPrefix +
        '\u5df2\u53d1\u9001\uff0c\u4f46\u5f53\u524d\u5e73\u53f0\u6682\u65f6\u65e0\u6cd5\u5b8c\u6574' +
        '\u786e\u8ba4\u632f\u52a8\u72b6\u6001';
      return {
        state: REMINDER_STATE_UNCERTAIN,
        success: true,
        notificationEnabled: true,
        notificationSent: true,
        vibrationMayBeLimited: true,
        message: message,
        userMessage: message,
        detailMessage: '\u901a\u77e5\u5df2\u6210\u529f\u53d1\u9001\uff0c\u4f46\u5f53\u524d\u5e73\u53f0' +
          '\u6682\u65f6\u65e0\u6cd5\u8bfb\u53d6\u901a\u77e5\u632f\u52a8\u72b6\u6001\uff0c' +
          '\u8bf7\u4ee5\u7cfb\u7edf\u901a\u77e5\u680f\u4e0e\u7cfb\u7edf\u8bbe\u7f6e\u4e3a\u51c6\u3002',
        logMessage: logPrefix + '\u5df2\u53d1\u9001\uff0c\u4f46\u5e73\u53f0\u6682\u65f6' +
          '\u65e0\u6cd5\u5b8c\u6574\u786e\u8ba4\u632f\u52a8\u72b6\u6001'
      };
    }

    const message = logPrefix + '\u5df2\u53d1\u9001';
    return {
      state: REMINDER_STATE_SENT,
      success: true,
      notificationEnabled: true,
      notificationSent: true,
      vibrationMayBeLimited: false,
      message: message,
      userMessage: message,
      detailMessage: '\u901a\u77e5\u5df2\u6210\u529f\u53d1\u9001\u5230\u7cfb\u7edf\u901a\u77e5\u680f\u3002',
      logMessage: message
    };
  }

  private static buildFailureResult(
    logPrefix: string,
    error: BusinessErrorLike
  ): ReminderSendResult {
    const errorCode = NativeReminderService.extractErrorCode(error);
    if (errorCode === 1600004 || errorCode === 1600005) {
      return NativeReminderService.buildPermissionMissingResult(logPrefix, errorCode);
    }

    const message = logPrefix + '\u53d1\u9001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5';
    const detailMessage = errorCode !== undefined
      ? '\u7cfb\u7edf\u8fd4\u56de\u9519\u8bef\u7801 ' + String(errorCode) + '\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002'
      : '\u7cfb\u7edf\u672a\u8fd4\u56de\u660e\u786e\u9519\u8bef\u7801\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002';
    return {
      state: REMINDER_STATE_FAILED,
      success: false,
      notificationEnabled: true,
      notificationSent: false,
      vibrationMayBeLimited: false,
      message: message,
      userMessage: message,
      detailMessage: detailMessage,
      logMessage: logPrefix + '\u53d1\u9001\u5931\u8d25',
      errorCode: errorCode
    };
  }

  private static buildPermissionMissingResult(
    logPrefix: string,
    errorCode?: number
  ): ReminderSendResult {
    const message = '\u5f53\u524d\u901a\u77e5\u6743\u9650\u672a\u5f00\u542f';
    return {
      state: REMINDER_STATE_PERMISSION_MISSING,
      success: false,
      notificationEnabled: false,
      notificationSent: false,
      vibrationMayBeLimited: true,
      message: message,
      userMessage: message,
      detailMessage: '\u5e94\u7528\u672a\u80fd\u786e\u8ba4\u901a\u77e5\u5df2\u5f00\u542f\u3002' +
        '\u8bf7\u5148\u5728\u7cfb\u7edf\u8bbe\u7f6e\u4e2d\u5141\u8bb8\u901a\u77e5\u540e\uff0c' +
        '\u518d\u91cd\u65b0\u53d1\u9001\u6d4b\u8bd5\u63d0\u9192\u3002',
      logMessage: logPrefix + '\u53d1\u9001\u5931\u8d25\uff1a\u901a\u77e5\u672a\u5f00\u542f',
      errorCode: errorCode
    };
  }

  private static extractErrorCode(error: BusinessErrorLike): number | undefined {
    if (error && typeof error.code === 'number') {
      return error.code;
    }
    return undefined;
  }
}
