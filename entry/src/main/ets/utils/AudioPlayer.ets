import { media } from '@kit.MediaKit';
import { Song } from '../model/Song';

/**
 * 音频播放器封装
 * 使用HarmonyOS AVPlayer进行音乐播放
 * 支持：播放队列、上一曲/下一曲、播放完成后自动切歌、收藏状态管理
 */
export class AudioPlayer {
  private static instance: AudioPlayer | null = null;
  private player: media.AVPlayer | null = null;
  private currentSong: Song | null = null;
  private isPlaying: boolean = false;
  private isPrepared: boolean = false;
  private currentPosition: number = 0;
  private duration: number = 0;

  /** 完整播放队列（按顺序排列的歌曲列表） */
  private queue: Song[] = [];
  /** 当前队列中的索引位置 */
  private queueIndex: number = -1;

  /** 播放状态回调 */
  onPlayStateChange: ((isPlaying: boolean) => void) | null = null;
  /** 进度回调（毫秒） */
  onProgressChange: ((position: number, duration: number) => void) | null = null;
  /** 播放完成回调（用于触发下一首） */
  onPlayComplete: (() => void) | null = null;

  private constructor() {}

  static getInstance(): AudioPlayer {
    if (!AudioPlayer.instance) {
      AudioPlayer.instance = new AudioPlayer();
    }
    return AudioPlayer.instance;
  }

  /**
   * 将歌曲加入播放队列末尾
   */
  enqueue(song: Song): void {
    this.queue.push(song);
  }

  /**
   * 从指定歌曲开始播放队列，清空旧队列并重建
   * @param startSong 起始歌曲，将在该歌曲之后依次接上后续歌曲
   */
  playQueue(startSong: Song): void {
    this.queue = [startSong];
    this.queueIndex = 0;
  }

  /**
   * 播放指定歌曲（替换整个队列并从该歌开始）
   */
  async play(song: Song): Promise<void> {
    // 如果是同一首歌且已准备好，直接播放
    if (this.currentSong && this.currentSong.songMid === song.songMid && this.isPrepared) {
      if (!this.isPlaying) {
        await this.player?.play();
        this.isPlaying = true;
        this.notifyPlayState();
      }
      return;
    }

    // 释放旧播放器
    await this.release();

    this.currentSong = song;
    this.isPrepared = false;
    this.currentPosition = 0;

    if (!song.playUrl) {
      throw new Error('歌曲播放地址为空');
    }

    this.player = await media.createAVPlayer();
    this.setupPlayerCallbacks();

    this.player.url = song.playUrl;
    await this.player.prepare();
    this.isPrepared = true;
    await this.player.play();
    this.isPlaying = true;
    this.notifyPlayState();
  }

  /**
   * 暂停播放
   */
  async pause(): Promise<void> {
    if (this.player && this.isPlaying) {
      await this.player.pause();
      this.isPlaying = false;
      this.notifyPlayState();
    }
  }

  /**
   * 继续播放
   */
  async resume(): Promise<void> {
    if (this.player && this.isPrepared && !this.isPlaying) {
      await this.player.play();
      this.isPlaying = true;
      this.notifyPlayState();
    }
  }

  /**
   * 停止播放
   */
  async stop(): Promise<void> {
    if (this.player) {
      await this.player.stop();
      this.isPlaying = false;
      this.currentPosition = 0;
      this.notifyPlayState();
    }
  }

  /**
   * 跳转到指定位置
   * @param position 毫秒
   */
  async seekTo(position: number): Promise<void> {
    if (this.player && this.isPrepared) {
      await this.player.seek(position);
      this.currentPosition = position;
    }
  }

  /**
   * 跳到队列中下一首并立即播放
   */
  async next(): Promise<void> {
    if (this.queue.length === 0 || this.queueIndex < 0) return;
    const nextIndex = this.queueIndex + 1;
    if (nextIndex >= this.queue.length) return; // 已是最后一首
    this.queueIndex = nextIndex;
    await this.play(this.queue[nextIndex]);
  }

  /**
   * 跳到队列中上一首并立即播放
   */
  async prev(): Promise<void> {
    if (this.queue.length === 0 || this.queueIndex <= 0) return;
    this.queueIndex--;
    await this.play(this.queue[this.queueIndex]);
  }

  /**
   * 释放播放器资源
   */
  async release(): Promise<void> {
    if (this.player) {
      try {
        await this.player.stop();
      } catch (e) {
        // ignore
      }
      try {
        await this.player.release();
      } catch (e) {
        // ignore
      }
      this.player = null;
      this.isPrepared = false;
      this.isPlaying = false;
      this.currentSong = null;
      this.currentPosition = 0;
      this.duration = 0;
      this.queue = [];
      this.queueIndex = -1;
    }
  }

  /** 获取当前歌曲 */
  getCurrentSong(): Song | null {
    return this.currentSong;
  }

  /** 是否正在播放 */
  getIsPlaying(): boolean {
    return this.isPlaying;
  }

  /** 获取当前队列 */
  getQueue(): Song[] {
    return this.queue;
  }

  /** 获取当前队列索引 */
  getQueueIndex(): number {
    return this.queueIndex;
  }

  /** 获取上一首歌（不在队列中时为null） */
  getPrevSong(): Song | null {
    if (this.queue.length === 0 || this.queueIndex <= 0) return null;
    return this.queue[this.queueIndex - 1];
  }

  /** 获取下一首歌（不在队列中时为null） */
  getNextSong(): Song | null {
    if (this.queue.length === 0 || this.queueIndex < 0 || this.queueIndex >= this.queue.length - 1) return null;
    return this.queue[this.queueIndex + 1];
  }

  /** 设置播放器回调 */
  private setupPlayerCallbacks(): void {
    if (!this.player) return;

    // 状态变化事件：统一处理播放/暂停/停止/完成
    this.player.on('stateChange', (state: media.AVPlayerState, reason: media.StateChangeReason) => {
      switch (state) {
        case 'playing':
          this.isPlaying = true;
          this.notifyPlayState();
          break;
        case 'paused':
        case 'stopped':
          this.isPlaying = false;
          this.notifyPlayState();
          break;
        case 'completed':
          this.isPlaying = false;
          this.notifyPlayState();
          if (this.onPlayComplete) {
            this.onPlayComplete();
          }
          break;
        case 'error':
          console.error('播放器状态变为error，reason：' + reason);
          break;
        default:
          break;
      }
    });

    this.player.on('error', (err: BusinessError) => {
      console.error('播放器错误：', err.message);
    });

    this.player.on('durationUpdate', (duration: number) => {
      this.duration = duration;
    });

    this.player.on('timeUpdate', (time: number) => {
      this.currentPosition = time;
      if (this.onProgressChange) {
        this.onProgressChange(this.currentPosition, this.duration);
      }
    });
  }

  private notifyPlayState(): void {
    if (this.onPlayStateChange) {
      this.onPlayStateChange(this.isPlaying);
    }
  }
}
