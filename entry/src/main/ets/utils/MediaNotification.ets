/**
 * 媒体通知服务（后台播放控制）
 *
 * 功能：
 *   - App 进入后台后，通过系统媒体通知栏显示当前歌曲信息
 *   - 用户可在通知栏直接执行：播放/暂停 / 上一曲 / 下一曲 / 关闭
 *   - 点击通知栏任意区域回到应用首页
 *
 * HarmonyOS 实现要点：
 *   - 使用 @kit.MediaKit 的 media.NotificationManager 创建媒体通知
 *   - 需在 module.json5 中声明 ohos.permission.MEDIA_CONSOLE 权限
 *   - 手表端通知会自动在状态栏显示"正在播放"图标（无需常驻卡片）
 *
 * TODO：
 *   - 接入 harmonyOS 官方 media.NotificationManager API（当前为框架桩，编译不报错）
 *   - 真实实现需使用 @Preview 标注测试或真机验证
 */

import { Song } from '../model/Song';
import { AudioPlayer } from './AudioPlayer';

// ── 通知动作类型定义 ──────────────────────────────────────────────

export type MediaAction = 'play' | 'pause' | 'next' | 'prev' | 'close';

export interface MediaNotificationOptions {
  /** 是否自动恢复上次进度（true=从断点继续播放） */
  resumeOnTap?: boolean;
}

// ── 管理器实现 ─────────────────────────────────────────────────────

export class MediaNotification {
  private static instance: MediaNotification | null = null;
  private player: AudioPlayer;
  private song: Song | null = null;
  private isPlaying: boolean = false;

  // 通知回调处理器（由 EntryAbility 注入实际行为）
  private onActionHandler: ((action: MediaAction) => void) | null = null;

  private constructor() {
    this.player = AudioPlayer.getInstance();
  }

  static getInstance(): MediaNotification {
    if (!MediaNotification.instance) {
      MediaNotification.instance = new MediaNotification();
    }
    return MediaNotification.instance;
  }

  /**
   * 由 Ability 层调用，注入通知按钮的实际点击响应
   * @param handler 收到 play/pause/next/prev/close 时调用的函数
   */
  setActionHandler(handler: (action: MediaAction) => void): void {
    this.onActionHandler = handler;
  }

  /**
   * 当歌曲切换时更新通知内容
   */
  updateSong(song: Song | null): void {
    this.song = song;
    this.notifyUI();
  }

  /**
   * 当播放状态切换时更新通知图标（播放 ↔ 暂停）
   */
  updatePlayingState(playing: boolean): void {
    this.isPlaying = playing;
    this.notifyUI();
  }

  /**
   * 手动触发一次通知刷新（用于切回前台后同步状态）
   */
  refresh(): void {
    this.notifyUI();
  }

  /** 处理来自通知栏的动作事件 */
  handleAction(action: MediaAction): void {
    if (!this.onActionHandler) return;
    this.onActionHandler(action);
  }

  // ── 私有方法 ────────────────────────────────────────────────────

  /**
   * 生成并显示媒体通知
   * TODO: 替换为真实 HarmonyOS MediaNotification API
   *
   * 参考真机实现（伪代码）：
   *   const notificationManager = media.getNotificationManager();
   *   await notificationManager.createNotification({
   *     id: 'qqmusic_bg_play',
   *     type: media.NotificationType.MEDIA,
   *     content: {
   *       title: song?.songName ?? 'QQ音乐',
   *       subTitle: song?.singerName ?? '',
   *       artwork: song?.albumCoverUrl,
   *       progress: { value: currentPosition, max: duration },
   *     },
   *     actions: [
   *       { type: 'prev', icon: 'ic_notify_prev' },
   *       { type: this.isPlaying ? 'pause' : 'play', icon: this.isPlaying ? 'ic_notify_pause' : 'ic_notify_play' },
   *       { type: 'next', icon: 'ic_notify_next' },
   *       { type: 'close', icon: 'ic_notify_close' },
   *     ],
   *     onTap: () => router.pushUrl({ url: 'pages/Index' }),
   *   });
   */
  private notifyUI(): void {
    if (!this.song) {
      console.info('[MediaNotify] 没有当前歌曲，跳过通知更新');
      return;
    }
    console.info(
      `[MediaNotify] ${this.isPlaying ? '▶ 播放中' : '⏸ 已暂停'} → ${this.song.songName} - ${this.song.singerName}`
    );
    // TODO: 调用 media.getNotificationManager().updateNotification(...) 推送真实通知
  }
}
