import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DeepLinkRouter } from '../deeplink/DeepLinkRouter';

const DOMAIN = 0x0001;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onCreate');
    this.handleWant(want);
  }

  /**
   * FUNCTIONAL — exp:// / exps:// / http(s) deep-link entry point.
   *
   * Cold start: fires in onCreate (above) before the window exists, so the
   * URI is queued in DeepLinkRouter until the launcher page subscribes.
   * Warm start: the ability is singleton (module.json5 launchType), so a
   * deep link arriving while the app runs lands here instead of a new
   * ability instance.
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onNewWant');
    this.handleWant(want);
  }

  private handleWant(want: Want): void {
    const uri = want.uri;
    if (uri !== undefined && uri.length > 0) {
      hilog.info(DOMAIN, TAG, 'Deep-link want: %{public}s', uri);
      DeepLinkRouter.instance.dispatch(uri);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load Index page: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Succeeded in loading Index page.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onBackground');
  }
}
