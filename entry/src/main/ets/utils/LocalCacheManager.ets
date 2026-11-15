/**
 * 本地离线缓存管理器
 *
 * 功能：
 *   - 下载歌曲音频（m4a）并缓存到设备本地目录 entry/profile/CachedData/
 *   - 检查某首歌曲是否已在本地缓存中（支持离线播放）
 *   - 清除指定歌曲缓存或全部缓存
 *
 * TODO（后续可接入 ServiceExtensionBackgroundTask / PkgAppProgressListener）：
 *   - 将 download() 改为在后台 TaskDispatcher 异步执行，避免阻塞 UI 线程
 *   - 接入 DownloadService（系统级下载服务）支持断点续传
 *   - 监听存储空间不足时自动清理最旧缓存
 */

import fs from '@ohos.file.fs';
import http from '@kit.NetworkKit';

const CACHE_DIR_NAME = 'CachedData';
const COVER_CACHE_DIR = 'covers';
const MAX_CACHE_SIZE_BYTES = 500 * 1024 * 1024; // 500MB

interface CachedEntry {
  mid: string;
  filePath: string;
  sizeBytes: number;
  downloadedAt: number;
}

export class LocalCacheManager {
  private static instance: LocalCacheManager | null = null;
  private cacheDir: fs.File | null = null;
  private coverDir: fs.File | null = null;
  private initDone: boolean = false;

  private constructor() {}

  static getInstance(): LocalCacheManager {
    if (!LocalCacheManager.instance) {
      LocalCacheManager.instance = new LocalCacheManager();
    }
    return LocalCacheManager.instance;
  }

  /**
   * 初始化缓存目录（必须在 Ability onCreate 或首页 aboutToAppear 中调用一次）
   */
  async init(context?: object): Promise<void> {
    if (this.initDone) return;
    try {
      // context 为 UIAbilityContext 时可获取 applicationContext.cacheDir
      // 这里使用相对路径兜底，实际使用时通过 getBundleCodeDir() 或 applicationInfo.cacheDir 指定
      const baseDir = fs.getFileStat(fs.getUiContext().fileDir).stat.isDirectory
        ? fs.getUiContext().fileDir
        : '/data/storage/el2/base';

      const cachePath = `${baseDir}/${CACHE_DIR_NAME}`;
      const coverPath = `${baseDir}/${CACHE_DIR_NAME}/${COVER_CACHE_DIR}`;

      let cacheFile = fs.openSync(cachePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      this.cacheDir = cacheFile.fd;
      fs.closeSync(cacheFile);

      let coverFile = fs.openSync(coverPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      this.coverDir = coverFile.fd;
      fs.closeSync(coverFile);

      this.initDone = true;
      console.info('[LocalCache] 初始化成功，路径:', cachePath);
    } catch (e) {
      console.error('[LocalCache] 初始化失败:', e);
      throw e;
    }
  }

  /**
   * 检查歌曲是否已缓存（本地有 m4a 文件）
   */
  isCached(songMid: string): boolean {
    if (!this.initDone) return false;
    const path = this.cachePath(songMid);
    try {
      const stat = fs.statSync(path);
      return stat.isFile && stat.size > 0;
    } catch {
      return false;
    }
  }

  /**
   * 获取已缓存歌曲的本地绝对路径，若未缓存则返回空字符串
   */
  getCachedFilePath(songMid: string): string {
    return this.isCached(songMid) ? this.cachePath(songMid) : '';
  }

  /**
   * 下载歌曲并缓存到本地
   * @param songMid   歌曲 mid
   * @param playUrl   完整的带 vkey 的播放地址
   * @param progress  进度回调（0~100）
   */
  async download(
    songMid: string,
    playUrl: string,
    progress?: (pct: number) => void
  ): Promise<string> {
    if (!this.initDone) {
      await this.init();
    }

    const destPath = this.cachePath(songMid);
    const file = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(playUrl, {
        method: http.RequestMethod.GET,
        responseType: http.HttpResponseType.ARRAYBUFFER,
        connectTimeout: 30000,
        readTimeout: 60000
      });

      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
        throw new Error(`下载失败，HTTP ${response.responseCode}`);
      }

      const buffer = response.result as ArrayBuffer;
      fs.writeSync(file.fd, buffer);
      fs.flushSync(file.fd);

      const size = buffer.byteLength;
      console.info(`[LocalCache] 已缓存: ${songMid} (${size} bytes)`);

      // 清理旧缓存以控制总大小
      await this.enforceSizeLimit();

      return destPath;
    } finally {
      fs.closeSync(file);
      httpRequest.destroy();
      progress?.(100);
    }
  }

  /**
   * 下载专辑封面图片
   */
  async downloadCover(url: string, songMid: string, progress?: (pct: number) => void): Promise<string> {
    if (!this.initDone) {
      await this.init();
    }
    const destPath = this.coverPath(songMid);
    const file = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    const httpRequest = http.createHttp();
    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        responseType: http.HttpResponseType.ARRAYBUFFER
      });
      if (resp.responseCode === 200 && resp.result instanceof ArrayBuffer) {
        fs.writeSync(file.fd, resp.result as ArrayBuffer);
        fs.flushSync(file.fd);
      }
      return destPath;
    } finally {
      fs.closeSync(file);
      httpRequest.destroy();
      progress?.(100);
    }
  }

  /**
   * 删除单首歌曲的缓存
   */
  removeCache(songMid: string): void {
    try { fs.unlinkSync(this.cachePath(songMid)); } catch (_) { /* ignore */ }
    try { fs.unlinkSync(this.coverPath(songMid)); } catch (_) { /* ignore */ }
  }

  /**
   * 清除全部缓存
   */
  async clearAll(): Promise<void> {
    if (!this.initDone) return;
    const entries = fs.listFileSync(this.cacheDir as unknown as string);
    for (const name of entries) {
      try { fs.unlinkSync(`${this.cacheDir}/${name}`); } catch (_) { /* ignore */ }
    }
    console.info('[LocalCache] 全部缓存已清除');
  }

  /**
   * 返回当前缓存总占用空间（字节）
   */
  getTotalCacheSize(): number {
    if (!this.initDone) return 0;
    let total = 0;
    try {
      const entries = fs.listFileSync(this.cacheDir as unknown as string);
      for (const name of entries) {
        try {
          total += fs.statSync(`${this.cacheDir}/${name}`).size;
        } catch (_) { /* ignore */ }
      }
    } catch (_) { /* ignore */ }
    return total;
  }

  // ── 私有工具方法 ───────────────────────────────────────────────

  private cachePath(songMid: string): string {
    return `${this.cacheDir}/song_${songMid}.m4a`;
  }

  private coverPath(songMid: string): string {
    return `${this.coverDir}/cover_${songMid}.jpg`;
  }

  /** 确保总缓存不超过限制，优先删除最早的文件 */
  private async enforceSizeLimit(): Promise<void> {
    let total = this.getTotalCacheSize();
    if (total <= MAX_CACHE_SIZE_BYTES) return;

    let entries: { name: string; time: number; size: number }[] = [];
    try {
      const names = fs.listFileSync(this.cacheDir as unknown as string);
      for (const n of names) {
        try {
          const s = fs.statSync(`${this.cacheDir}/${n}`);
          if (s.isFile) entries.push({ name: n, time: s.atime ?? 0, size: s.size });
        } catch (_) { /* ignore */ }
      }
    } catch (_) { /* ignore */ }

    entries.sort((a, b) => a.time - b.time); // 最早的在前

    for (const e of entries) {
      if (total <= MAX_CACHE_SIZE_BYTES) break;
      try {
        fs.unlinkSync(`${this.cacheDir}/${e.name}`);
        total -= e.size;
      } catch (_) { /* ignore */ }
    }
  }
}
