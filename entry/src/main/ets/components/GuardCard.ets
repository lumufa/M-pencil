import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_PILL_GREEN_BG,
  HOME_PILL_GREEN_FG,
  HOME_PILL_RED_BG,
  HOME_PILL_RED_FG,
  HOME_TEXT_PRIMARY
} from './HomeTheme';

@Component
export struct GuardCard {
  @StorageLink('appView.backgroundMonitoringEnabled') backgroundMonitoringEnabled: boolean = true;
  @StorageLink('appView.backgroundMonitoringLimited') backgroundMonitoringLimited: boolean = false;
  @StorageLink('appView.notificationPermissionGranted') notificationPermissionGranted: boolean = false;

  private isBackgroundOk(): boolean {
    return this.backgroundMonitoringEnabled && !this.backgroundMonitoringLimited;
  }

  private backgroundPillText(): string {
    if (!this.backgroundMonitoringEnabled) {
      return '已关闭';
    }
    if (this.backgroundMonitoringLimited) {
      return '受限';
    }
    return '运行中';
  }

  build() {
    Row({ space: 12 }) {
      this.buildTile('后台守护', this.backgroundPillText(), this.isBackgroundOk());
      this.buildTile('通知权限', this.notificationPermissionGranted ? '已开启' : '未开启', this.notificationPermissionGranted);
    }
    .width('100%');
  }

  @Builder
  private buildTile(title: string, pill: string, ok: boolean) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(HOME_TEXT_PRIMARY)
        .layoutWeight(1);

      Text(pill)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(ok ? HOME_PILL_GREEN_FG : HOME_PILL_RED_FG)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(999)
        .backgroundColor(ok ? HOME_PILL_GREEN_BG : HOME_PILL_RED_BG);
    }
    .layoutWeight(1)
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER })
    .alignItems(VerticalAlign.Center);
  }
}
