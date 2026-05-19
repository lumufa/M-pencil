import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { createDefaultReminderSettings, ReminderSettings } from '../models/AppStatusModel';

const STORE_NAME = 'm_pencil_guardian_settings';

export class AppSettingsService {
  private preferenceStore?: preferences.Preferences;

  async load(context?: common.UIAbilityContext): Promise<ReminderSettings> {
    const defaults = createDefaultReminderSettings();
    if (!context) {
      return defaults;
    }

    try {
      const store = await this.getStore(context);
      return {
        reminderThreshold: Number(await store.get('reminderThreshold', defaults.reminderThreshold)),
        repeatReminderEnabled: Boolean(await store.get('repeatReminderEnabled', defaults.repeatReminderEnabled)),
        repeatReminderInterval: Number(await store.get('repeatReminderInterval', defaults.repeatReminderInterval)),
        backgroundMonitoringEnabled: Boolean(
          await store.get('backgroundMonitoringEnabled', defaults.backgroundMonitoringEnabled)
        ),
        vibrationEnabled: Boolean(await store.get('vibrationEnabled', defaults.vibrationEnabled)),
        onboardingCompleted: Boolean(await store.get('onboardingCompleted', defaults.onboardingCompleted))
      };
    } catch (_) {
      return defaults;
    }
  }

  async save(context: common.UIAbilityContext | undefined, settings: ReminderSettings): Promise<void> {
    if (!context) {
      return;
    }

    try {
      const store = await this.getStore(context);
      await store.put('reminderThreshold', settings.reminderThreshold);
      await store.put('repeatReminderEnabled', settings.repeatReminderEnabled);
      await store.put('repeatReminderInterval', settings.repeatReminderInterval);
      await store.put('backgroundMonitoringEnabled', settings.backgroundMonitoringEnabled);
      await store.put('vibrationEnabled', settings.vibrationEnabled);
      await store.put('onboardingCompleted', settings.onboardingCompleted);
      await store.flush();
    } catch (_) {
      // Ignore persistence errors to avoid blocking the main flow.
    }
  }

  async update(
    context: common.UIAbilityContext | undefined,
    current: ReminderSettings,
    patch: Partial<ReminderSettings>
  ): Promise<ReminderSettings> {
    const nextSettings: ReminderSettings = {
      ...current,
      ...patch
    };
    await this.save(context, nextSettings);
    return nextSettings;
  }

  private async getStore(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (!this.preferenceStore) {
      this.preferenceStore = await preferences.getPreferences(context, STORE_NAME);
    }
    return this.preferenceStore;
  }
}
