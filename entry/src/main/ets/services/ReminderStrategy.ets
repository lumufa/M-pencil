import { AppStatusModel } from '../models/AppStatusModel';

export interface ReminderDecision {
  shouldTrigger: boolean;
  reason: 'threshold-crossed' | 'repeat-reminder' | 'none';
  nextLastReminderTime: number;
}

export class ReminderStrategy {
  private cycleArmed: boolean = true;
  private lastReminderAt: number = 0;

  evaluate(previous: AppStatusModel, next: AppStatusModel, now: number = Date.now()): ReminderDecision {
    if (!next.isConnected || !next.isCharging || !next.monitoringEnabled) {
      this.resetCycle();
      return {
        shouldTrigger: false,
        reason: 'none',
        nextLastReminderTime: this.lastReminderAt
      };
    }

    const threshold = next.reminderThreshold;
    const crossedThreshold = previous.batteryLevel < threshold && next.batteryLevel >= threshold;
    const alreadyAtThreshold = next.batteryLevel >= threshold;

    if (this.cycleArmed && (crossedThreshold || alreadyAtThreshold)) {
      this.cycleArmed = false;
      this.lastReminderAt = now;
      return {
        shouldTrigger: true,
        reason: 'threshold-crossed',
        nextLastReminderTime: this.lastReminderAt
      };
    }

    if (next.repeatReminderEnabled && alreadyAtThreshold) {
      const intervalMs = Math.max(1, next.repeatReminderInterval) * 60 * 1000;
      if (this.lastReminderAt > 0 && now - this.lastReminderAt >= intervalMs) {
        this.lastReminderAt = now;
        return {
          shouldTrigger: true,
          reason: 'repeat-reminder',
          nextLastReminderTime: this.lastReminderAt
        };
      }
    }

    return {
      shouldTrigger: false,
      reason: 'none',
      nextLastReminderTime: this.lastReminderAt
    };
  }

  resetCycle(): void {
    this.cycleArmed = true;
    this.lastReminderAt = 0;
  }

  markReminderSent(at: number = Date.now()): void {
    this.lastReminderAt = at;
    this.cycleArmed = false;
  }

  getLastReminderAt(): number {
    return this.lastReminderAt;
  }
}
