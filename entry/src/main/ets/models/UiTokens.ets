export interface ResponsiveTokens {
  pagePadding: number;
  contentMaxWidth: number;
  sectionGap: number;
  columnGap: number;
  cardRadius: number;
  cardPadding: number;
  compactCardPadding: number;
  dualColumn: boolean;
  leftColumnWeight: number;
  rightColumnWeight: number;
  titleSize: number;
  subtitleSize: number;
  bodySize: number;
  captionSize: number;
  heroMinHeight: number;
  heroTopInset: number;
  heroBottomInset: number;
  ringSize: number;
  ringStroke: number;
  actionGroupHeight: number;
  statusPillHeight: number;
  switchHitSize: number;
  buttonHeight: number;
  testButtonWidthRatio: number;
  tipDotSize: number;
}

export function getResponsiveTokens(pageWidth: number): ResponsiveTokens {
  if (pageWidth >= 1240) {
    return {
      pagePadding: 44,
      contentMaxWidth: 1320,
      sectionGap: 18,
      columnGap: 18,
      cardRadius: 30,
      cardPadding: 26,
      compactCardPadding: 22,
      dualColumn: true,
      leftColumnWeight: 11,
      rightColumnWeight: 9,
      titleSize: 34,
      subtitleSize: 18,
      bodySize: 17,
      captionSize: 13,
      heroMinHeight: 610,
      heroTopInset: 20,
      heroBottomInset: 18,
      ringSize: 274,
      ringStroke: 7,
      actionGroupHeight: 50,
      statusPillHeight: 40,
      switchHitSize: 44,
      buttonHeight: 54,
      testButtonWidthRatio: 0.76,
      tipDotSize: 26
    };
  }

  if (pageWidth >= 900) {
    return {
      pagePadding: 34,
      contentMaxWidth: 1080,
      sectionGap: 16,
      columnGap: 16,
      cardRadius: 28,
      cardPadding: 24,
      compactCardPadding: 20,
      dualColumn: true,
      leftColumnWeight: 11,
      rightColumnWeight: 9,
      titleSize: 30,
      subtitleSize: 17,
      bodySize: 16,
      captionSize: 12,
      heroMinHeight: 540,
      heroTopInset: 18,
      heroBottomInset: 16,
      ringSize: 236,
      ringStroke: 6,
      actionGroupHeight: 46,
      statusPillHeight: 38,
      switchHitSize: 42,
      buttonHeight: 52,
      testButtonWidthRatio: 0.8,
      tipDotSize: 24
    };
  }

  return {
    pagePadding: 18,
    contentMaxWidth: 680,
    sectionGap: 14,
    columnGap: 14,
    cardRadius: 24,
    cardPadding: 18,
    compactCardPadding: 16,
    dualColumn: false,
    leftColumnWeight: 1,
    rightColumnWeight: 1,
    titleSize: 25,
    subtitleSize: 15,
    bodySize: 15,
    captionSize: 12,
    heroMinHeight: 450,
    heroTopInset: 14,
    heroBottomInset: 14,
    ringSize: 196,
    ringStroke: 5,
    actionGroupHeight: 42,
    statusPillHeight: 34,
    switchHitSize: 40,
    buttonHeight: 48,
    testButtonWidthRatio: 0.88,
    tipDotSize: 22
  };
}
