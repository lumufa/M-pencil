import { HOME_HERO_BG } from './HomeTheme';
import { AppUiBridge } from '../services/AppUiBridge';

@Component
export struct MainHeroCard {
  @StorageLink('appView.batteryLevel') batteryLevel: number = 0;
  @StorageLink('appView.batteryPercentText') batteryPercentText: string = '--%';
  @StorageLink('appView.batteryStateText') batteryStateText: string = '等待状态';
  @StorageLink('appView.heroStatusText') heroStatusText: string = '等待连接';
  @StorageLink('appView.heroSyncText') heroSyncText: string = '--';
  @StorageLink('appView.isConnected') isConnected: boolean = false;
  @StorageLink('appView.canRetry') canRetry: boolean = true;
  @StorageLink('appView.reminderThreshold') reminderThreshold: number = 85;

  private handleTap(): void {
    if (this.canRetry) {
      AppUiBridge.retryMonitoring();
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.heroStatusText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.92)')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(this.isConnected ? '已连接' : '未连接')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(999)
          .backgroundColor('rgba(255, 255, 255, 0.18)');
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Row({ space: 36 }) {
        Stack() {
          Progress({
            value: this.batteryLevel,
            total: 100,
            type: ProgressType.Ring
          })
            .width(170)
            .height(170)
            .color('#FFFFFF')
            .backgroundColor('rgba(255, 255, 255, 0.18)')
            .style({ strokeWidth: 10 });

          Text(this.batteryPercentText)
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width(170)
        .height(170);

        Column({ space: 18 }) {
          this.buildInfo('状态', this.batteryStateText);
          this.buildInfo('阈值', this.reminderThreshold + '%');
          this.buildInfo('同步', this.heroSyncText);
        }
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 24, bottom: 8 });
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 22, bottom: 22 })
    .borderRadius(24)
    .backgroundColor(HOME_HERO_BG)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.handleTap();
    });
  }

  @Builder
  private buildInfo(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(12)
        .fontColor('rgba(255, 255, 255, 0.65)');
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .alignItems(HorizontalAlign.Start);
  }
}
