import deviceInfo from '@ohos.deviceInfo';
import promptAction from '@ohos.promptAction';
import Want from '@ohos.app.ability.Want';
import { AppContextHolder } from '../services/AppContextHolder';
import { AppUiBridge } from '../services/AppUiBridge';

const PAGE_BG = '#F5F5F0';
const SURFACE_BG = '#FFFFFF';
const SURFACE_BORDER = '#F0EFE8';
const TEXT_PRIMARY = '#1A1A1A';
const TEXT_SECONDARY = '#777777';
const TEXT_PLACEHOLDER = '#B0B0B0';
const DIVIDER_COLOR = '#F0EFE8';
const ACCENT_COLOR = '#1A6B5A';
const INPUT_BG = '#FAFAF7';

const CONTENT_MAX_WIDTH = 960;
const FEEDBACK_EMAIL = 'lumufa591@outlook.com';

@Component
export struct FeedbackPage {
  @StorageLink('appView.pageWidth') pageWidth: number = 900;
  @StorageLink('appView.appVersion') appVersion: string = '1.0.0';
  @StorageLink('appView.isConnected') isConnected: boolean = false;
  @StorageLink('appView.deviceName') deviceName: string = 'M-Pencil';

  @State private description: string = '';
  @State private contact: string = '';

  private getSidePadding(): number {
    const extra = (this.pageWidth - CONTENT_MAX_WIDTH) / 2;
    return Math.max(32, Math.round(extra));
  }

  private getDeviceModel(): string {
    try {
      return deviceInfo.marketName || deviceInfo.productModel || '未知设备';
    } catch (_) {
      return '未知设备';
    }
  }

  private getSystemVersion(): string {
    try {
      return deviceInfo.osFullName || '未知系统版本';
    } catch (_) {
      return '未知系统版本';
    }
  }

  private getConnectionStatusText(): string {
    return this.isConnected ? '已连接 (' + this.deviceName + ')' : '未连接';
  }

  private buildMailBody(): string {
    let body = this.description.trim();
    if (this.contact.trim().length > 0) {
      body += '\n\n联系方式：' + this.contact.trim();
    }
    body += '\n\n--- 设备信息 ---';
    body += '\nApp 版本：' + this.appVersion;
    body += '\n系统版本：' + this.getSystemVersion();
    body += '\n设备型号：' + this.getDeviceModel();
    body += '\nM-Pencil 状态：' + this.getConnectionStatusText();
    return body;
  }

  private buildMailSubject(): string {
    return '[M-Pencil Guardian 反馈] v' + this.appVersion + ' / ' + this.getDeviceModel();
  }

  private async submitFeedback(): Promise<void> {
    if (this.description.trim().length === 0) {
      promptAction.showToast({ message: '请填写问题描述', duration: 1800 });
      return;
    }

    const subject = this.buildMailSubject();
    const body = this.buildMailBody();
    const context = AppContextHolder.get();
    if (!context) {
      promptAction.showToast({ message: '暂时无法发送反馈', duration: 1800 });
      return;
    }

    try {
      const want: Want = {
        action: 'ohos.want.action.sendToData',
        uri: 'mailto:' + FEEDBACK_EMAIL,
        parameters: {
          'mail.subject': subject,
          'mail.body': body
        }
      };
      await context.startAbility(want);
    } catch (_) {
      promptAction.showToast({ message: '未找到邮箱客户端，请安装后重试', duration: 2500 });
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildHeader();
        this.buildFormSection();
        this.buildDeviceInfoSection();
        this.buildSubmitButton();
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
        AppUiBridge.openSettings();
      });

      Text('问题反馈')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_PRIMARY);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildFormSection() {
    Column({ space: 0 }) {
      Column() {
        Text('问题描述')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_SECONDARY)
          .margin({ bottom: 8 });

        TextArea({ placeholder: '请描述你遇到的问题，例如连接异常、通知未触发等', text: this.description })
          .fontSize(15)
          .fontColor(TEXT_PRIMARY)
          .placeholderColor(TEXT_PLACEHOLDER)
          .backgroundColor(INPUT_BG)
          .borderRadius(12)
          .padding(14)
          .height(140)
          .onChange((value: string) => {
            this.description = value;
          });
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 });

      Divider().strokeWidth(1).color(DIVIDER_COLOR);

      Column() {
        Text('联系方式（选填）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_SECONDARY)
          .margin({ bottom: 8 });

        TextInput({ placeholder: '邮箱或其他联系方式，方便回复你', text: this.contact })
          .fontSize(15)
          .fontColor(TEXT_PRIMARY)
          .placeholderColor(TEXT_PLACEHOLDER)
          .backgroundColor(INPUT_BG)
          .borderRadius(12)
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .onChange((value: string) => {
            this.contact = value;
          });
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 18 });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(SURFACE_BG)
    .borderRadius(20)
    .border({ width: 1, color: SURFACE_BORDER });
  }

  @Builder
  private buildDeviceInfoSection() {
    Column({ space: 0 }) {
      Text('以下信息将自动附带在反馈中')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 4, bottom: 6 });

      Column({ space: 0 }) {
        this.buildInfoRow('App 版本', this.appVersion);
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildInfoRow('系统版本', this.getSystemVersion());
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildInfoRow('设备型号', this.getDeviceModel());
        Divider().strokeWidth(1).color(DIVIDER_COLOR);
        this.buildInfoRow('M-Pencil 状态', this.getConnectionStatusText());
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
  private buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_PRIMARY)
        .layoutWeight(1);

      Text(value)
        .fontSize(14)
        .fontColor(TEXT_SECONDARY);
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildSubmitButton() {
    Button('提交反馈')
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .width('100%')
      .height(48)
      .borderRadius(14)
      .backgroundColor(ACCENT_COLOR)
      .onClick(() => {
        void this.submitFeedback();
      });
  }
}
