import { preferences } from '@kit.ArkData';

/**
 * 本地收藏管理器
 * 使用Preferences存储收藏的歌曲mid列表，每次启动时懒加载到内存Set中
 */
export class FavoritesManager {
  private static instance: FavoritesManager | null = null;
  private static readonly STORE_NAME = 'qqmusic_watch_prefs';
  private static readonly FAV_KEY = 'favorite_song_mids';

  private store: preferences.Preferences | null = null;
  private favorites: Set<string> = new Set();
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): FavoritesManager {
    if (!FavoritesManager.instance) {
      FavoritesManager.instance = new FavoritesManager();
    }
    return FavoritesManager.instance;
  }

  /** 初始化：读取持久化数据到内存 */
  async init(): Promise<void> {
    if (this.initialized || this.store !== null) return;
    try {
      this.store = await preferences.getPreferences(FavoritesManager.STORE_NAME);
      const raw = await this.store!.get(FavoritesManager.FAV_KEY, '[]') as string;
      try {
        const mids: string[] = JSON.parse(raw);
        this.favorites = new Set(mids);
      } catch {
        this.favorites = new Set();
      }
      this.initialized = true;
    } catch (e) {
      console.error('FavoritesManager init failed:', e);
    }
  }

  /** 是否已收藏 */
  isFavorite(songMid: string): boolean {
    return this.favorites.has(songMid);
  }

  /** 切换收藏状态（add/remove）并持久化 */
  async toggleFavorite(songMid: string): Promise<boolean> {
    if (!this.initialized) await this.init();
    if (this.favorites.has(songMid)) {
      this.favorites.delete(songMid);
    } else {
      this.favorites.add(songMid);
    }
    await this.persist();
    return this.favorites.has(songMid);
  }

  /** 添加到收藏 */
  async addToFavorites(songMid: string): Promise<void> {
    if (!this.initialized) await this.init();
    this.favorites.add(songMid);
    await this.persist();
  }

  /** 从收藏移除 */
  async removeFromFavorites(songMid: string): Promise<void> {
    if (!this.initialized) await this.init();
    this.favorites.delete(songMid);
    await this.persist();
  }

  /** 返回所有已收藏的mid列表 */
  getFavoriteMids(): string[] {
    return Array.from(this.favorites);
  }

  /** 持久化到Preferences */
  private async persist(): Promise<void> {
    if (!this.store) return;
    await this.store.put(FavoritesManager.FAV_KEY, JSON.stringify(Array.from(this.favorites)));
    await this.store.flush();
  }
}
