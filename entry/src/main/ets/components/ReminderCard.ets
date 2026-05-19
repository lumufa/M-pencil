import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_PILL_GREEN_FG,
  HOME_SOFT_GREEN,
  HOME_TEXT_PRIMARY,
  HOME_TEXT_SECONDARY,
  HOME_TEXT_TERTIARY
} from './HomeTheme';
import { AppUiBridge } from '../services/AppUiBridge';

@Component
export struct ReminderCard {
  @StorageLink('appView.reminderThreshold') alertThreshold: number = 85;
  @StorageLink('appView.repeatReminderEnabled') repeatEnabled: boolean = false;
  @StorageLink('appView.repeatReminderInterval') repeatInterval: number = 20;

  build() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text('提醒设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(HOME_TEXT_PRIMARY);
          Text('建议 80% - 85% 之间')
            .fontSize(12)
            .fontColor(HOME_TEXT_SECONDARY);
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        Text(String(this.alertThreshold) + '%')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(HOME_PILL_GREEN_FG);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Column() {
        Slider({
          value: this.alertThreshold,
          min: 60,
          max: 100,
          step: 1
        })
          .width('100%')
          .selectedColor(HOME_PILL_GREEN_FG)
          .blockColor(HOME_PILL_GREEN_FG)
          .trackColor('#EDECE4')
          .trackThickness(4)
          .onChange((value: number) => {
            AppUiBridge.updateReminderSettings({
              reminderThreshold: Math.round(value)
            });
          });

        Row() {
          Text('60%')
            .fontSize(11)
            .fontColor(HOME_TEXT_TERTIARY);
          Text('100%')
            .fontSize(11)
            .fontColor(HOME_TEXT_TERTIARY);
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 6 });
      }
      .width('100%');

      Row() {
        Column({ space: 4 }) {
          Text('重复提醒')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(HOME_TEXT_PRIMARY);
          Text('达到阈值后每 ' + String(this.repeatInterval) + ' 分钟提醒一次')
            .fontSize(11)
            .fontColor(HOME_TEXT_SECONDARY);
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        Toggle({ type: ToggleType.Switch, isOn: this.repeatEnabled })
          .selectedColor(HOME_PILL_GREEN_FG)
          .switchPointColor('#FFFFFF')
          .onChange((isOn: boolean) => {
            AppUiBridge.updateReminderSettings({
              repeatReminderEnabled: isOn
            });
          });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Button('发送测试提醒')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(HOME_PILL_GREEN_FG)
        .width('100%')
        .height(44)
        .borderRadius(12)
        .backgroundColor(HOME_SOFT_GREEN)
        .onClick(() => {
          AppUiBridge.sendTestReminder();
        });
    }
    .width('100%')
    .padding(20)
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER });
  }
}
