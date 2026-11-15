import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { window, configurationCommon } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { media } from '@kit.MediaKit';
import { AppState } from '../ets/AppState';
import { LocalCacheManager } from '../ets/utils/LocalCacheManager';
import { QQLoginManager } from '../ets/utils/QQLoginManager';
import { MediaNotification } from '../ets/utils/MediaNotification';
import { AudioPlayer } from '../ets/utils/AudioPlayer';
import { FavoritesManager } from '../ets/utils/FavoritesManager';

/**
 * 应用入口 Ability
 *
 * 启动时完成以下初始化：
 *   1. 恢复 QQ 登录态（持久化存储）
 *   2. 初始化本地缓存目录
 *   3. 配置音频会话（支持后台播放）
 *   4. 注册后台任务监听（可选，HarmonyOS 4.1+）
 */
export default class EntryAbility extends UIAbility {
  private appState: AppState = new AppState();
  private mediaNotify: MediaNotification = MediaNotification.getInstance();
  private audioSession: media.AudioRenderer | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onCreate');
    await this.initServices();
  }

  onDestroy(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onDestroy');
    this.releaseAudioSession();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onWindowStageCreate');

    // 配置音频会话 — 确保切后台后仍能播放
    this.setupAudioSession();

    // 将媒体通知的操作路由到播放器
    this.mediaNotify.setActionHandler((action) => this.handleMediaAction(action));

    windowStage.loadContent('pages/Index', (err) => {
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
    // 切回前台时刷新通知栏状态
    const player = AudioPlayer.getInstance();
    this.mediaNotify.updatePlayingState(player.getIsPlaying());
  }

  onBackground(): void {
    hilog.info(0x0000, 'QQMusicWatch', 'Ability onBackground');
    // 进入后台：刷新通知显示当前播放状态
    const player = AudioPlayer.getInstance();
    this.mediaNotify.updateSong(player.getCurrentSong());
    this.mediaNotify.updatePlayingState(player.getIsPlaying());
  }

  // ── 私有方法 ────────────────────────────────────────────────────

  /** 初始化各项服务（登录态、缓存、收藏） */
  private async initServices(): Promise<void> {
    try {
      await this.appState.refreshFromStorage();
      await LocalCacheManager.getInstance().init();
      await QQLoginManager.getInstance().init();
      await FavoritesManager.getInstance().init();
      hilog.info(0x0000, 'QQMusicWatch', '所有服务初始化完成');
    } catch (e) {
      hilog.error(0x0000, 'QQMusicWatch', '服务初始化异常: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 配置音频会话，允许后台播放
   *
   * TODO：
   *   - HarmonyOS 穿戴设备对音频会话的支持有限，部分机型可能需要申请
   *     system_profile 中的 ohos.permission.AUTO_BACKGROUND_RUNNING 才能稳定保活
   *   - 真机调试时请在 DevEco Studio → Run Configuration → Permissions 勾选相关项
   */
  private setupAudioSession(): void {
    try {
      this.audioSession = media.createAudioRenderer({
        sourceType: media.SourceType.FILE,
        surfaceId: ''
      });
      hilog.info(0x0000, 'QQMusicWatch', 'AudioRenderer 创建成功，支持后台播放');
    } catch (e) {
      hilog.warn(0x0000, 'QQMusicWatch', 'AudioRenderer 初始化失败，将依赖 AVPlayer 后台能力: %{public}s', JSON.stringify(e));
    }
  }

  private releaseAudioSession(): void {
    if (this.audioSession) {
      try {
        this.audioSession.release();
      } catch (_) { /* ignore */ }
      this.audioSession = null;
    }
  }

  /**
   * 处理来自媒体通知的动作
   */
  private handleMediaAction(action: 'play' | 'pause' | 'next' | 'prev' | 'close'): void {
    const player = AudioPlayer.getInstance();
    switch (action) {
      case 'play':
        player.resume().catch(() => {});
        break;
      case 'pause':
        player.pause().catch(() => {});
        break;
      case 'next':
        player.next().catch(() => {});
        break;
      case 'prev':
        player.prev().catch(() => {});
        break;
      case 'close':
        player.stop().catch(() => {});
        break;
    }
  }
}
