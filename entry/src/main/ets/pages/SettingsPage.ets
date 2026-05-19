import { AppUiBridge } from '../services/AppUiBridge';

const PAGE_BG = '#F5F5F0';
const SURFACE_BG = '#FFFFFF';
const SURFACE_BORDER = '#F0EFE8';
const TEXT_PRIMARY = '#1A1A1A';
const TEXT_SECONDARY = '#777777';
const DIVIDER_COLOR = '#F0EFE8';
const ACCENT_COLOR = '#1A6B5A';
const ACCENT_BG = '#E8F5F0';
const WARNING_COLOR = '#C23B3B';
const WARNING_BG = '#FCE8E8';

const CONTENT_MAX_WIDTH = 960;

@Component
export struct SettingsPage {
  @StorageLink('appView.pageWidth') pageWidth: number = 900;
  @StorageLink('appView.reminderThreshold') reminderThreshold: number = 85;
  @StorageLink('appView.repeatReminderEnabled') repeatReminderEnabled: boolean = false;
  @StorageLink('appView.vibrationEnabled') vibrationEnabled: boolean = false;
  @StorageLink('appView.backgroundMonitoringEnabled') backgroundMonitoringEnabled: boolean = true;
  @StorageLink('appView.notificationPermissionGranted') notificationPermissionGranted: boolean = false;
  @StorageLink('appView.backgroundMonitoringLimited') backgroundMonitoringLimited: boolean = false;
  @StorageLink('appView.appVersion') appVersion: string = '1.0.0';

  private getSidePadding(): number {
    const extra = (this.pageWidth - CONTENT_MAX_WIDTH) / 2;
    return Math.max(32, Math.round(extra));
  }

  private getGuardStatusText(): string {
    if (!this.backgroundMonitoringEnabled) {
      return '已关闭';
    }
    if (this.backgroundMonitoringLimited) {
      return '受限';
    }
    return '运行中';
  }

  private isGuardOk(): boolean {
    return this.backgroundMonitoringEnabled && !this.backgroundMonitoringLimited;
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildHeader();
        this.buildReminderSection();
        this.buildRuntimeSection();
        this.buildDataSection();
        this.buildSupportSection();
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .padding({
        left: this.getSidePadding(),
        right: this.getSidePadding(),
        top: 72,
        bottom: 40
      });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(PAGE_BG);
  }

  @Builder
  private buildHeader() {
    Row({ space: 14 }) {
      Stack() {
        Text('‹')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_PRIMARY);
      }
      .width(48)
      .height(48)
      .borderRadius(14)
      .backgroundColor(SURFACE_BG)
      .border({ width: 1, color: SURFACE_BORDER })
      .onClick(() => {
        AppUiBridge.goHome();
      });

      Text('设置')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_PRIMARY);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildSectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(TEXT_SECONDARY)
      .width('100%')
      .padding({ left: 4, bottom: 6 });
  }

  @Builder
  private buildReminderSection() {
    Column() {
      this.buildSectionTitle('提醒');

      Column({ space: 0 }) {
        this.buildThresholdItem();
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildRepeatItem();
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildVibrationItem();
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildTestItem();
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(SURFACE_BG)
      .borderRadius(20)
      .border({ width: 1, color: SURFACE_BORDER });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildThresholdItem() {
    Column({ space: 14 }) {
      Row() {
        Text('提醒阈值')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_PRIMARY)
          .layoutWeight(1);

        Text(String(this.reminderThreshold) + '%')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(ACCENT_COLOR)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(999)
          .backgroundColor(ACCENT_BG);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Slider({
        value: this.reminderThreshold,
        min: 60,
        max: 100,
        step: 1
      })
        .width('100%')
        .selectedColor(ACCENT_COLOR)
        .blockColor(ACCENT_COLOR)
        .trackColor('#DDE3E8')
        .trackThickness(4)
        .onChange((value: number) => {
          AppUiBridge.updateReminderSettings({
            reminderThreshold: Math.round(value)
          });
        });
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 });
  }

  @Builder
  private buildRepeatItem() {
    Row() {
      Text('重复提醒')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: this.repeatReminderEnabled })
        .selectedColor(ACCENT_COLOR)
        .onChange((isOn: boolean) => {
          AppUiBridge.updateReminderSettings({
            repeatReminderEnabled: isOn
          });
        });
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildVibrationItem() {
    Row() {
      Text('振动提醒')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Toggle({ type: ToggleType.Switch, isOn: this.vibrationEnabled })
        .selectedColor(ACCENT_COLOR)
        .onChange((isOn: boolean) => {
          AppUiBridge.updateReminderSettings({
            vibrationEnabled: isOn
          });
        });
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildTestItem() {
    Row() {
      Text('发送测试通知')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Button('发送')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .height(34)
        .padding({ left: 16, right: 16 })
        .borderRadius(999)
        .backgroundColor(ACCENT_COLOR)
        .onClick(() => {
          AppUiBridge.sendTestReminder();
        });
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildRuntimeSection() {
    Column() {
      this.buildSectionTitle('运行');

      Column({ space: 0 }) {
        this.buildStatusRow(
          '通知权限',
          this.notificationPermissionGranted ? '已开启' : '未开启',
          this.notificationPermissionGranted
        );
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildStatusRow(
          '后台守护',
          this.getGuardStatusText(),
          this.isGuardOk()
        );
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildActionRow('系统设置', '前往', () => {
          AppUiBridge.openSystemSettings();
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(SURFACE_BG)
      .borderRadius(20)
      .border({ width: 1, color: SURFACE_BORDER });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildDataSection() {
    Column() {
      this.buildSectionTitle('数据');

      Column({ space: 0 }) {
        this.buildActionRow('清除电量历史', '清除', () => {
          AppUiBridge.clearBatteryHistory();
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(SURFACE_BG)
      .borderRadius(20)
      .border({ width: 1, color: SURFACE_BORDER });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildSupportSection() {
    Column() {
      this.buildSectionTitle('关于');

      Column({ space: 0 }) {
        this.buildValueRow('版本', this.appVersion);
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildActionRow('使用指南', '查看', () => {
          AppUiBridge.openGuide();
        });
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildActionRow('问题反馈', '前往', () => {
          AppUiBridge.openFeedback();
        });
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildActionRow('隐私政策', '查看', () => {
          AppUiBridge.openPrivacy();
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(SURFACE_BG)
      .borderRadius(20)
      .border({ width: 1, color: SURFACE_BORDER });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildStatusRow(title: string, value: string, ok: boolean) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(ok ? ACCENT_COLOR : WARNING_COLOR)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(999)
        .backgroundColor(ok ? ACCENT_BG : WARNING_BG);
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildValueRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Text(value)
        .fontSize(14)
        .fontColor(TEXT_SECONDARY);
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildActionRow(title: string, actionLabel: string, handler: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Text(actionLabel + ' ›')
        .fontSize(14)
        .fontColor(TEXT_SECONDARY);
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      handler();
    });
  }
}
