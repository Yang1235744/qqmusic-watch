/**
 * 应用全局状态管理
 * 使用 @StorageProp / @StorageLink 在页面间共享数据
 *
 * 所有页面对应此文件中的字段，实现跨页面实时同步：
 *   - isLoggedIn         是否已登录（QQ）
 *   - currentUser        当前用户信息
 *   - currentSong        当前播放歌曲（@StorageLink 双向绑定）
 *   - isPlaying          当前播放状态（@StorageLink）
 *   - syncToCloudEnabled 是否开启云端收藏同步（需先登录）
 */

import { Song } from './model/Song';
import { QQLoginUser, QQLoginManager } from './utils/QQLoginManager';

export class AppState {
  /** 是否已登录 QQ */
  isLoggedIn: boolean = QQLoginManager.getInstance().isLoggedIn;

  /** 当前登录的用户（null = 未登录） */
  currentUser: QQLoginUser | null = QQLoginManager.getInstance().currentUser;

  /** 当前正在播放的歌曲 — 用 @StorageLink 在 Player/Index/Search 间同步 */
  currentSong: Song | null = null;

  /** 当前是否在播放 — 用 @StorageLink 在所有含迷你播放条的页面同步 */
  isPlaying: boolean = false;

  /** 是否开启了"登录后自动同步收藏到云端"开关 */
  syncToCloudEnabled: boolean = false;

  /** 从持久化存储读取上次登录状态（需在入口调用 refreshFromStorage） */
  async refreshFromStorage(): Promise<void> {
    const mgr = QQLoginManager.getInstance();
    await mgr.init();
    this.isLoggedIn = mgr.isLoggedIn;
    this.currentUser = mgr.currentUser;
  }
}
