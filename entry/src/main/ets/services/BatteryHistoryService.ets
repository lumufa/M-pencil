import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';

export interface BatteryPoint {
  ts: number;
  level: number;
  charging: boolean;
}

export type HistoryRange = '24h' | '7d' | '30d';

const STORE_NAME = 'm_pencil_battery_history';
const STORE_KEY = 'points';
const MAX_POINTS = 2000;
const MIN_INTERVAL_MS = 60 * 1000;
const FORCE_INTERVAL_MS = 5 * 60 * 1000;
const RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

interface RawPoint {
  ts?: number;
  level?: number;
  charging?: boolean;
}

export class BatteryHistoryService {
  private static singleton?: BatteryHistoryService;

  static instance(): BatteryHistoryService {
    if (!BatteryHistoryService.singleton) {
      BatteryHistoryService.singleton = new BatteryHistoryService();
    }
    return BatteryHistoryService.singleton;
  }

  private store?: preferences.Preferences;
  private cache: BatteryPoint[] = [];
  private lastIngestTs: number = 0;
  private lastIngestLevel: number = -1;
  private dirty: boolean = false;
  private flushing: boolean = false;
  private version: number = 0;

  async init(context?: common.UIAbilityContext): Promise<void> {
    if (!context) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
      const raw = String(await this.store.get(STORE_KEY, '[]'));
      this.cache = this.deserialize(raw);
      this.purgeExpired();
      if (this.cache.length > 0) {
        const last = this.cache[this.cache.length - 1];
        this.lastIngestTs = last.ts;
        this.lastIngestLevel = last.level;
      }
      this.version += 1;
      AppStorage.Set('appView.batteryHistoryVersion', this.version);
    } catch (_) {
      this.cache = [];
    }
  }

  ingest(level: number, charging: boolean, timestamp: number): void {
    if (level < 0 || level > 100) {
      return;
    }
    const ts = timestamp > 0 ? timestamp : Date.now();
    const sinceLast = ts - this.lastIngestTs;
    const levelChanged = level !== this.lastIngestLevel;

    if (sinceLast < MIN_INTERVAL_MS) {
      return;
    }
    if (!levelChanged && sinceLast < FORCE_INTERVAL_MS) {
      return;
    }

    this.cache.push({ ts, level, charging });
    this.lastIngestTs = ts;
    this.lastIngestLevel = level;
    this.purgeExpired();
    this.dirty = true;
    this.version += 1;
    AppStorage.Set('appView.batteryHistoryVersion', this.version);
    void this.flush();
  }

  clear(): void {
    this.cache = [];
    this.lastIngestTs = 0;
    this.lastIngestLevel = -1;
    this.dirty = true;
    this.version += 1;
    AppStorage.Set('appView.batteryHistoryVersion', this.version);
    void this.flush();
  }

  getLastLevel(): number {
    if (this.cache.length === 0) {
      return -1;
    }
    return this.cache[this.cache.length - 1].level;
  }

  getMinLevelWithin(windowMs: number): number {
    const cutoff = Date.now() - windowMs;
    let min = -1;
    for (const point of this.cache) {
      if (point.ts < cutoff) {
        continue;
      }
      if (min < 0 || point.level < min) {
        min = point.level;
      }
    }
    return min;
  }


  getSeries(range: HistoryRange): BatteryPoint[] {
    const cutoff = Date.now() - this.rangeToMs(range);
    const result: BatteryPoint[] = [];
    for (const point of this.cache) {
      if (point.ts >= cutoff) {
        result.push(point);
      }
    }
    return result;
  }

  getSummary(range: HistoryRange): { min: number; max: number; count: number } {
    const points = this.getSeries(range);
    if (points.length === 0) {
      return { min: 0, max: 0, count: 0 };
    }
    let min = points[0].level;
    let max = points[0].level;
    for (const point of points) {
      if (point.level < min) {
        min = point.level;
      }
      if (point.level > max) {
        max = point.level;
      }
    }
    return { min, max, count: points.length };
  }

  private rangeToMs(range: HistoryRange): number {
    if (range === '24h') {
      return 24 * 60 * 60 * 1000;
    }
    if (range === '7d') {
      return 7 * 24 * 60 * 60 * 1000;
    }
    return 30 * 24 * 60 * 60 * 1000;
  }

  private purgeExpired(): void {
    const cutoff = Date.now() - RETENTION_MS;
    const filtered: BatteryPoint[] = [];
    for (const point of this.cache) {
      if (point.ts >= cutoff) {
        filtered.push(point);
      }
    }
    this.cache = filtered.length > MAX_POINTS
      ? filtered.slice(filtered.length - MAX_POINTS)
      : filtered;
  }

  private async flush(): Promise<void> {
    if (!this.store || this.flushing || !this.dirty) {
      return;
    }
    this.flushing = true;
    try {
      const payload = JSON.stringify(this.cache);
      await this.store.put(STORE_KEY, payload);
      await this.store.flush();
      this.dirty = false;
    } catch (_) {
      // ignore persistence errors to avoid blocking the main flow
    } finally {
      this.flushing = false;
    }
  }

  private deserialize(raw: string): BatteryPoint[] {
    try {
      const parsed: unknown = JSON.parse(raw);
      if (!Array.isArray(parsed)) {
        return [];
      }
      const result: BatteryPoint[] = [];
      for (const item of parsed) {
        const candidate = item as RawPoint;
        if (candidate && typeof candidate.ts === 'number' && typeof candidate.level === 'number') {
          result.push({
            ts: candidate.ts,
            level: candidate.level,
            charging: candidate.charging === true
          });
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }
}
