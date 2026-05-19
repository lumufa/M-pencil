import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_DIVIDER,
  HOME_TEXT_PRIMARY,
  HOME_TEXT_SECONDARY,
  HOME_TEXT_TERTIARY
} from './HomeTheme';
import { AppUiBridge } from '../services/AppUiBridge';

type SupportAction = 'system' | 'feedback' | 'privacy' | 'permission';

@Component
export struct SystemSupportCard {
  @StorageLink('appView.appVersion') appVersion: string = '1.0.0';

  private handleAction(action: SupportAction): void {
    switch (action) {
      case 'system':
        AppUiBridge.openSystemSettings();
        break;
      case 'feedback':
        AppUiBridge.openFeedback();
        break;
      case 'privacy':
        AppUiBridge.openPrivacy();
        break;
      case 'permission':
        AppUiBridge.openGuide();
        break;
    }
  }

  build() {
    Column() {
      Text('系统与支持')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(HOME_TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: 14 });

      this.buildRow('去系统设置', '打开蓝牙、通知等系统权限', 'system');
      this.buildDivider();
      this.buildRow('问题反馈', '告诉我们遇到的问题', 'feedback');
      this.buildDivider();
      this.buildRow('隐私政策', '了解我们如何处理你的数据', 'privacy');
      this.buildDivider();
      this.buildRow('权限用途说明', '查看所需权限及用途', 'permission');

      Text('版本 ' + this.appVersion)
        .fontSize(11)
        .fontColor(HOME_TEXT_TERTIARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 });
    }
    .width('100%')
    .padding(20)
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER })
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildDivider() {
    Divider()
      .strokeWidth(1)
      .color(HOME_DIVIDER)
      .margin({ top: 10, bottom: 10 });
  }

  @Builder
  private buildRow(title: string, detail: string, action: SupportAction) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(HOME_TEXT_PRIMARY);
        Text(detail)
          .fontSize(11)
          .fontColor(HOME_TEXT_SECONDARY);
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Text('›')
        .fontSize(20)
        .fontColor(HOME_TEXT_TERTIARY);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.handleAction(action);
    });
  }
}
