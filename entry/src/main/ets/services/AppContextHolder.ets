import common from '@ohos.app.ability.common';

export class AppContextHolder {
  private static uiAbilityContext?: common.UIAbilityContext;

  static set(context: common.UIAbilityContext): void {
    AppContextHolder.uiAbilityContext = context;
  }

  static get(): common.UIAbilityContext | undefined {
    return AppContextHolder.uiAbilityContext;
  }
}
