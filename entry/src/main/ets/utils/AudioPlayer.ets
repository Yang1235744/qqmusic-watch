import { media } from '@kit.MediaKit';
import { Song } from '../model/Song';

/**
 * 音频播放器封装
 * 使用HarmonyOS AudioRenderer进行音乐播放
 */
export class AudioPlayer {
  private static instance: AudioPlayer | null = null;
  private player: media.AVPlayer | null = null;
  private currentSong: Song | null = null;
  private isPlaying: boolean = false;
  private isPrepared: boolean = false;
  private currentPosition: number = 0;
  private duration: number = 0;

  /** 播放状态回调 */
  onPlayStateChange: ((isPlaying: boolean) => void) | null = null;
  /** 进度回调（毫秒） */
  onProgressChange: ((position: number, duration: number) => void) | null = null;
  /** 播放完成回调 */
  onPlayComplete: (() => void) | null = null;

  private constructor() {}

  static getInstance(): AudioPlayer {
    if (!AudioPlayer.instance) {
      AudioPlayer.instance = new AudioPlayer();
    }
    return AudioPlayer.instance;
  }

  /**
   * 播放指定歌曲
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
