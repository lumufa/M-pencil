import { getResponsiveTokens } from '../models/UiTokens';
import { HOME_HERO_BG, HOME_CARD_BG } from './HomeTheme';

@Component
export struct AlertBanner {
  pageWidth: number = 900;
  title: string = '测试提醒已发送';
  detail: string = '请留意振动和弹窗效果。';

  build() {
    const tokens = getResponsiveTokens(this.pageWidth);
    Column() {
      Text(this.title)
        .fontSize(tokens.bodySize + 1)
        .fontWeight(FontWeight.Bold)
        .fontColor(HOME_CARD_BG);
      Text(this.detail)
        .fontSize(tokens.captionSize + 1)
        .fontColor('rgba(255, 255, 255, 0.84)')
        .margin({ top: 4 });
    }
    .width('100%')
    .padding({ left: tokens.cardPadding, right: tokens.cardPadding, top: 14, bottom: 14 })
    .borderRadius(tokens.cardRadius)
    .backgroundColor(HOME_HERO_BG)
    .margin({ bottom: tokens.sectionGap });
  }
}
