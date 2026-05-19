import {
  HOME_CARD_BG,
  HOME_CARD_BORDER,
  HOME_HERO_BG,
  HOME_PAGE_BG,
  HOME_PILL_GREEN_BG,
  HOME_PILL_GREEN_FG,
  HOME_TEXT_PRIMARY,
  HOME_TEXT_SECONDARY
} from '../components/HomeTheme';
import { AppUiBridge } from '../services/AppUiBridge';

const CONTENT_MAX_WIDTH = 720;

@Component
export struct OnboardingPage {
  @StorageLink('appView.pageWidth') pageWidth: number = 900;

  private getSidePadding(): number {
    const extra = (this.pageWidth - CONTENT_MAX_WIDTH) / 2;
    return Math.max(32, Math.round(extra));
  }

  private handleComplete(): void {
    AppUiBridge.finishOnboarding();
  }

  build() {
    Scroll() {
      Column({ space: 32 }) {
        this.buildHero();
        this.buildSteps();
        this.buildActions();
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: this.getSidePadding(),
        right: this.getSidePadding(),
        top: 96,
        bottom: 48
      });
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(HOME_PAGE_BG);
  }

  @Builder
  private buildHero() {
    Column({ space: 16 }) {
      Stack() {
        Text('↑')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');
      }
      .width(64)
      .height(64)
      .borderRadius(20)
      .backgroundColor(HOME_HERO_BG);

      Text('M-Pencil')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(HOME_TEXT_PRIMARY);

      Text('在合适电量提醒你取下手写笔')
        .fontSize(15)
        .fontColor(HOME_TEXT_SECONDARY);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildSteps() {
    Column({ space: 14 }) {
      this.buildStep('1', '吸附手写笔到平板边缘');
      this.buildStep('2', '阈值建议 80% – 85%');
      this.buildStep('3', '收到提醒后手动取下');
    }
    .width('100%');
  }

  @Builder
  private buildStep(index: string, title: string) {
    Row({ space: 16 }) {
      Text(index)
        .width(32)
        .height(32)
        .borderRadius(16)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(HOME_PILL_GREEN_FG)
        .backgroundColor(HOME_PILL_GREEN_BG);

      Text(title)
        .fontSize(15)
        .fontColor(HOME_TEXT_PRIMARY)
        .layoutWeight(1);
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .borderRadius(20)
    .backgroundColor(HOME_CARD_BG)
    .border({ width: 1, color: HOME_CARD_BORDER })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildActions() {
    Column({ space: 12 }) {
      Button('开始使用')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width('100%')
        .height(52)
        .borderRadius(999)
        .backgroundColor(HOME_HERO_BG)
        .onClick(() => {
          this.handleComplete();
        });
    }
    .width('100%');
  }
}
