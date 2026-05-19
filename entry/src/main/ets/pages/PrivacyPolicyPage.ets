import { AppUiBridge } from '../services/AppUiBridge';

const PAGE_BG = '#F5F5F0';
const SURFACE_BG = '#FFFFFF';
const SURFACE_BORDER = '#F0EFE8';
const TEXT_PRIMARY = '#1A1A1A';
const TEXT_SECONDARY = '#777777';
const ACCENT_COLOR = '#1A6B5A';

const CONTENT_MAX_WIDTH = 960;

const PRIVACY_POLICY_TEXT =
  'M-Pencil Guardian 隐私政策\n\n' +
  '最后更新日期：2026 年 4 月 12 日\n\n' +
  '感谢你使用 M-Pencil Guardian。本隐私政策说明我们如何处理你在使用本应用时产生的信息。\n\n' +

  '一、我们收集哪些信息\n\n' +
  '本应用在运行过程中会使用以下信息：\n' +
  '- 蓝牙设备信息：包括 M-Pencil 设备名称、连接状态和电量数据，用于实现核心的电量监测功能。\n' +
  '- 电量历史记录：用于在应用内展示电量变化趋势。\n' +
  '- 设备基础信息：当你主动提交问题反馈时，应用会附带设备型号、系统版本等基础信息，帮助我们定位问题。\n\n' +

  '二、数据如何存储\n\n' +
  '所有数据仅存储在你的本地设备上，不会上传至任何服务器。我们没有后端服务，也不会收集、传输或存储你的个人数据。\n\n' +

  '三、第三方 SDK\n\n' +
  '本应用不包含任何第三方数据收集 SDK。应用仅使用 HarmonyOS 系统提供的标准 API。\n\n' +

  '四、权限说明\n\n' +
  '本应用需要以下系统权限：\n' +
  '- 蓝牙权限：用于扫描、连接和监测 M-Pencil 手写笔。\n' +
  '- 通知权限：用于在电量达到阈值时发送提醒通知。\n' +
  '- 后台运行权限：用于在应用切到后台后持续监测电量，确保及时提醒。\n\n' +

  '五、数据删除\n\n' +
  '你可以随时通过「设置 > 清除电量历史」删除本地保存的电量记录。卸载应用将自动清除所有本地数据，不会有任何残留。\n\n' +

  '六、联系我们\n\n' +
  '如果你对本隐私政策有任何疑问，或在使用过程中遇到问题，可以通过以下方式联系我们：\n' +
  '邮箱：lumufa591@outlook.com';

@Component
export struct PrivacyPolicyPage {
  @StorageLink('appView.pageWidth') pageWidth: number = 900;

  private getSidePadding(): number {
    const extra = (this.pageWidth - CONTENT_MAX_WIDTH) / 2;
    return Math.max(32, Math.round(extra));
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildHeader();
        this.buildContent();
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

      Text('隐私政策')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_PRIMARY);
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildContent() {
    Column() {
      Text(PRIVACY_POLICY_TEXT)
        .fontSize(15)
        .fontColor(TEXT_PRIMARY)
        .lineHeight(26)
        .width('100%');
    }
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BG)
    .borderRadius(20)
    .border({ width: 1, color: SURFACE_BORDER });
  }
}
