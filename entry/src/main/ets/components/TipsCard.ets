import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_PILL_GREEN_FG,
  HOME_TEXT_PRIMARY
} from './HomeTheme';

@Component
export struct TipsCard {
  @State expanded: boolean = false;

  private toggle(): void {
    this.expanded = !this.expanded;
  }

  build() {
    Column() {
      Row() {
        Text('使用指南')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(HOME_TEXT_PRIMARY)
          .layoutWeight(1);

        Text(this.expanded ? '收起' : '展开')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(HOME_PILL_GREEN_FG);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.toggle();
      });

      if (this.expanded) {
        Column({ space: 10 }) {
          this.buildTip('1', '将手写笔吸附到设备边缘');
          this.buildTip('2', '阈值建议 80% – 85%');
          this.buildTip('3', '收到提醒后手动取下');
        }
        .width('100%')
        .margin({ top: 16 });
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER })
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildTip(index: string, title: string) {
    Row({ space: 12 }) {
      Text(index)
        .width(22)
        .height(22)
        .borderRadius(11)
        .textAlign(TextAlign.Center)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(HOME_PILL_GREEN_FG)
        .backgroundColor('#DCF2EA');

      Text(title)
        .fontSize(13)
        .fontColor(HOME_TEXT_PRIMARY)
        .layoutWeight(1);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }
}
