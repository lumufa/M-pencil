import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_HERO_BG,
  HOME_PILL_GREEN_BG,
  HOME_PILL_GREEN_FG,
  HOME_TEXT_PRIMARY,
  HOME_TEXT_TERTIARY
} from './HomeTheme';
import {
  BatteryHistoryService,
  BatteryPoint,
  HistoryRange
} from '../services/BatteryHistoryService';

const CHART_HEIGHT: number = 180;
const CHART_PADDING_X: number = 12;
const CHART_PADDING_Y: number = 16;

@Component
export struct BatteryHistoryCard {
  @StorageLink('appView.batteryHistoryVersion') @Watch('onDataChanged') historyVersion: number = 0;
  @State @Watch('onDataChanged') range: HistoryRange = '24h';
  @State private canvasWidth: number = 320;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private onDataChanged(): void {
    this.draw();
  }

  private getPoints(): BatteryPoint[] {
    return BatteryHistoryService.instance().getSeries(this.range);
  }

  private getSummary(): { min: number; max: number; count: number } {
    return BatteryHistoryService.instance().getSummary(this.range);
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('电量历史')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(HOME_TEXT_PRIMARY)
          .layoutWeight(1);

        Row({ space: 6 }) {
          this.buildRangeTab('24h', '24小时');
          this.buildRangeTab('7d', '7天');
          this.buildRangeTab('30d', '30天');
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Stack() {
        Canvas(this.context)
          .width('100%')
          .height(CHART_HEIGHT)
          .onReady(() => {
            this.draw();
          })
          .onAreaChange((_old: Area, newArea: Area) => {
            const width = Number(newArea.width);
            if (width > 0 && Math.abs(width - this.canvasWidth) > 1) {
              this.canvasWidth = width;
              this.draw();
            }
          });

        if (this.getSummary().count === 0) {
          Text('暂无数据')
            .fontSize(13)
            .fontColor(HOME_TEXT_TERTIARY);
        }
      }
      .width('100%')
      .height(CHART_HEIGHT);

      Row() {
        this.buildSummary('最低', this.getSummary().min);
        Blank().layoutWeight(1);
        this.buildSummary('最高', this.getSummary().max);
      }
      .width('100%');
    }
    .width('100%')
    .padding(20)
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER })
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildRangeTab(value: HistoryRange, label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.range === value ? HOME_PILL_GREEN_FG : HOME_TEXT_TERTIARY)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(999)
      .backgroundColor(this.range === value ? HOME_PILL_GREEN_BG : '#00000000')
      .onClick(() => {
        this.range = value;
      });
  }

  @Builder
  private buildSummary(label: string, value: number) {
    Row({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(HOME_TEXT_TERTIARY);
      Text(value > 0 ? value + '%' : '--')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(HOME_TEXT_PRIMARY);
    }
  }

  private draw(): void {
    const ctx = this.context;
    const width = this.canvasWidth;
    const height = CHART_HEIGHT;
    if (width <= 0) {
      return;
    }
    ctx.clearRect(0, 0, width, height);

    const innerLeft = CHART_PADDING_X;
    const innerRight = width - CHART_PADDING_X;
    const innerTop = CHART_PADDING_Y;
    const innerBottom = height - CHART_PADDING_Y;
    const innerWidth = innerRight - innerLeft;
    const innerHeight = innerBottom - innerTop;

    // baseline grid (0%, 50%, 100%)
    ctx.strokeStyle = '#EFEEE7';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 2; i++) {
      const y = innerTop + (innerHeight * i) / 2;
      ctx.beginPath();
      ctx.moveTo(innerLeft, y);
      ctx.lineTo(innerRight, y);
      ctx.stroke();
    }

    const points = this.getPoints();
    if (points.length === 0) {
      return;
    }

    const rangeMs = this.rangeMs();
    const endTs = Date.now();
    const startTs = endTs - rangeMs;

    const xs: number[] = [];
    const ys: number[] = [];
    for (const point of points) {
      const tx = (point.ts - startTs) / rangeMs;
      const clampedTx = tx < 0 ? 0 : (tx > 1 ? 1 : tx);
      const x = innerLeft + clampedTx * innerWidth;
      const y = innerBottom - (point.level / 100) * innerHeight;
      xs.push(x);
      ys.push(y);
    }

    // area fill
    ctx.beginPath();
    ctx.moveTo(xs[0], innerBottom);
    for (let i = 0; i < xs.length; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.lineTo(xs[xs.length - 1], innerBottom);
    ctx.closePath();
    ctx.fillStyle = 'rgba(26, 107, 90, 0.12)';
    ctx.fill();

    // line stroke
    ctx.beginPath();
    ctx.moveTo(xs[0], ys[0]);
    for (let i = 1; i < xs.length; i++) {
      ctx.lineTo(xs[i], ys[i]);
    }
    ctx.strokeStyle = HOME_HERO_BG;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.stroke();

    // last point dot
    const lastIndex = xs.length - 1;
    ctx.beginPath();
    ctx.arc(xs[lastIndex], ys[lastIndex], 4, 0, Math.PI * 2);
    ctx.fillStyle = HOME_HERO_BG;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(xs[lastIndex], ys[lastIndex], 6, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(26, 107, 90, 0.25)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  private rangeMs(): number {
    if (this.range === '24h') {
      return 24 * 60 * 60 * 1000;
    }
    if (this.range === '7d') {
      return 7 * 24 * 60 * 60 * 1000;
    }
    return 30 * 24 * 60 * 60 * 1000;
  }
}
