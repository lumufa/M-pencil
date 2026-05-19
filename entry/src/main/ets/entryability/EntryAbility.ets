import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { AppContextHolder } from '../services/AppContextHolder';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    AppContextHolder.set(this.context as common.UIAbilityContext);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index');
  }
}
