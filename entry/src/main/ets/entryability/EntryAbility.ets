import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 应用入口Ability
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onWindowStageCreate');
    // 加载首页
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'QQMusicWatch', '加载首页失败: %{public}s', err.message);
        return;
      }
      hilog.info(0x0000, 'QQMusicWatch', '首页加载成功');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onBackground');
  }
}
