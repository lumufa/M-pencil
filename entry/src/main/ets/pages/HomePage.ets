import { MainHeroCard } from '../components/MainHeroCard';
import { BatteryHistoryCard } from '../components/BatteryHistoryCard';
import { GuardCard } from '../components/GuardCard';
import { TipsCard } from '../components/TipsCard';
import {
  HOME_PAGE_BG,
  HOME_HERO_BG,
  HOME_TEXT_PRIMARY,
  HOME_TEXT_SECONDARY,
  HOME_CARD_BG,
  HOME_CARD_BORDER
} from '../components/HomeTheme';
import { AppUiBridge } from '../services/AppUiBridge';

const CONTENT_MAX_WIDTH = 960;

@Component
export struct HomePage {
  @StorageLink('appView.pageWidth') pageWidth: number = 900;

  private getSidePadding(): number {
    const extra = (this.pageWidth - CONTENT_MAX_WIDTH) / 2;
    return Math.max(32, Math.round(extra));
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        this.buildHeader();
        this.buildBody();
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
    .backgroundColor(HOME_PAGE_BG);
  }

  @Builder
  private buildBody() {
    Column({ space: 16 }) {
      MainHeroCard();
      BatteryHistoryCard();
      GuardCard();
      TipsCard();
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildHeader() {
    Row() {
      Row({ space: 14 }) {
        Stack() {
          Text('↑')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF');
        }
        .width(48)
        .height(48)
        .borderRadius(14)
        .backgroundColor(HOME_HERO_BG);

        Text('M-Pencil')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(HOME_TEXT_PRIMARY);
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center);

      Button('设置')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(HOME_TEXT_PRIMARY)
        .height(44)
        .padding({ left: 20, right: 20 })
        .borderRadius(14)
        .backgroundColor(HOME_CARD_BG)
        .border({ width: 1, color: HOME_CARD_BORDER })
        .onClick(() => {
          AppUiBridge.openSettings();
        });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }
}
