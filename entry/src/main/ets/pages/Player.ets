import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../AppState';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { LocalCacheManager } from '../utils/LocalCacheManager';
import { Song } from '../model/Song';

/**
 * 播放器页面
 *
 * 新增功能（相比之前版本）：
 *   - 单曲离线下载按钮（下载后可以在"离线"Tab播放）
 *   - 已缓存歌曲标记显示
 */
@Entry
@Component
struct Player {
  @State currentSong: Song | null = null;
  @State isPlaying: boolean = false;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State showLyrics: boolean = false;
  @State currentLyricIndex: number = 0;
  @State isDownloading: boolean = false;
  @State downloadProgress: number = 0;
  @State isCached: boolean = false;

  private appState: AppState = new AppState();
  private player: AudioPlayer = AudioPlayer.getInstance();
  private cacheMgr: LocalCacheManager = LocalCacheManager.getInstance();

  aboutToAppear(): void {
    this.currentSong = this.player.getCurrentSong();
    this.isPlaying = this.player.getIsPlaying();
    this.isCached = !!this.currentSong && this.cacheMgr.isCached(this.currentSong.songMid);

    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
      this.currentSong = this.player.getCurrentSong();
      this.isCached = !!this.currentSong && this.cacheMgr.isCached(this.currentSong.songMid);
    };

    this.player.onProgressChange = (position, dur) => {
      this.currentPosition = position;
      this.duration = dur;
      this.updateLyricLine(position);
    };

    this.player.onPlayComplete = () => {
      this.isPlaying = false;
      this.player.next().catch(() => {});
    };
  }

  // ── 播放控制 ────────────────────────────────────────────────────

  togglePlay(): void {
    this.isPlaying ? this.player.pause() : this.player.resume();
  }

  stop(): void {
    this.player.stop();
  }

  async nextSong(): Promise<void> {
    try { await this.player.next(); } catch { promptAction.showToast({ message: '没有下一首' }); }
  }

  async prevSong(): Promise<void> {
    try { await this.player.prev(); } catch { promptAction.showToast({ message: '没有上一首' }); }
  }

  onSliderChange(value: number): void {
    this.player.seekTo(value);
  }

  formatTime(ms: number): string {
    if (ms <= 0) return '00:00';
    const s = Math.floor(ms / 1000);
    return `${Math.floor(s / 60).toString().padStart(2, '0')}:${(s % 60).toString().padStart(2, '0')}`;
  }

  getCurrentLyricLine(): string {
    if (!this.currentSong || !this.currentSong.lyricsText) return '';
    const lines = this.currentSong.lyricsText.split('\n').filter(l => l.trim());
    if (this.duration <= 0) return lines[0] || '';
    const ratio = this.currentPosition / this.duration;
    const idx = Math.min(Math.floor(ratio * lines.length), lines.length - 1);
    return lines[Math.max(idx, 0)] || '';
  }

  updateLyricLine(ms: number): void {
    if (!this.currentSong || !this.currentSong.lyricsText) return;
    if (this.duration <= 0) return;
    const lines = this.currentSong.lyricsText.split('\n').filter(l => l.trim());
    this.currentLyricIndex = Math.min(Math.floor((ms / this.duration) * lines.length), lines.length - 1);
  }

  // ── 离线下载 ────────────────────────────────────────────────────

  /** 下载当前歌曲到本地缓存 */
  async downloadCurrentSong(): Promise<void> {
    if (!this.currentSong) return;
    if (this.isDownloading) return;
    if (this.currentSong.isVip) {
      promptAction.showToast({ message: 'VIP歌曲暂不支持离线下载' });
      return;
    }
    if (!this.currentSong.playUrl) {
      promptAction.showToast({ message: '请先播放该歌曲以获取地址' });
      return;
    }

    this.isDownloading = true;
    this.downloadProgress = 0;
    try {
      await this.cacheMgr.download(
        this.currentSong.songMid,
        this.currentSong.playUrl,
        (pct) => { this.downloadProgress = pct; }
      );
      this.isCached = true;
      promptAction.showToast({ message: '✅ 已保存到本地，可在「离线」Tab播放' });
    } catch (e) {
      promptAction.showToast({ message: '下载失败：' + (e as Error).message });
    } finally {
      this.isDownloading = false;
      this.downloadProgress = 0;
    }
  }

  build() {
    Scroll() {
      Column() {
        // 顶部栏
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor(Color.White)
            .onClick(() => router.back())
          Text('正在播放')
            .fontSize(16).fontColor(Color.White).layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button(this.showLyrics ? '歌词' : '关闭')
            .fontSize(12).fontColor('#FF31C27C').backgroundColor('#1A1A1A')
            .borderRadius(12).padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => { this.showLyrics = !this.showLyrics; })
        }
        .width('100%').height(56).padding({ left: 12, right: 12 })

        if (this.currentSong) {
          // 唱片封面
          Column() {
            if (this.currentSong.albumCoverUrl) {
              Image(this.currentSong.albumCoverUrl)
                .width(180).height(180).borderRadius(90).objectFit(ImageFit.Cover)
            } else {
              Column() {
                Image($r('sys.media.ohos_ic_public_sound')).width(80).height(80).fillColor('#666666')
              }
              .width(180).height(180).borderRadius(90).backgroundColor('#222222')
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%').margin({ top: 20 }).justifyContent(FlexAlign.Center)

          // 歌曲信息
          Column() {
            Text(this.currentSong.songName)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
            Text(this.currentSong.singerName).fontSize(14).fontColor('#B0B0B0').margin({ top: 8 })
            Text(this.currentSong.albumName).fontSize(12).fontColor('#808080').margin({ top: 4 })
            Row({ space: 6 }) {
              if (this.currentSong.isVip) {
                Text('VIP').fontSize(11).fontColor('#FF9900').backgroundColor('#332200')
                  .borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 })
              }
              if (this.isCached) {
                Text('本地缓存').fontSize(11).fontColor('#31C27C').backgroundColor('#0A2E1F')
                  .borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 })
              }
            }.margin({ top: 6 })
          }
          .width('100%').padding({ left: 24, right: 24 }).margin({ top: 16 })

          // 歌词区
          if (this.showLyrics && this.currentSong.lyricsText) {
            Column() {
              ForEach(this.currentSong.lyricsText.split('\n').filter(l => l.trim()),
                (line: string, idx: number) => {
                  Text(line)
                    .fontSize(idx === this.currentLyricIndex ? 14 : 12)
                    .fontColor(idx === this.currentLyricIndex ? '#FF31C27C' : '#555555')
                    .fontWeight(idx === this.currentLyricIndex ? FontWeight.Bold : FontWeight.Normal)
                    .margin({ top: 4, bottom: 4 })
                }, (line: string, idx: number) => idx.toString())
            }
            .width('100%').padding({ left: 24, right: 24 }).margin({ top: 16 })
            .height(120).overflow(Overflow.Scroll)
          } else if (this.showLyrics) {
            Text('暂无歌词').fontSize(13).fontColor('#555555').margin({ top: 16 })
          }

          // 进度条
          Column() {
            Slider({ value: this.currentPosition, min: 0,
              max: this.duration > 0 ? this.duration : 100, step: 1000 })
              .width('100%').blockColor('#FF31C27C').trackColor('#333333')
              .selectedColor('#FF31C27C')
              .onChange((v: number) => this.onSliderChange(v))
            Row() {
              Text(this.formatTime(this.currentPosition)).fontSize(12).fontColor('#B0B0B0')
              Blank()
              Text(this.formatTime(this.duration)).fontSize(12).fontColor('#B0B0B0')
            }.width('100%').margin({ top: 6 })
          }
          .width('100%').padding({ left: 24, right: 24 }).margin({ top: 20 })

          // 控制按钮行
          Row() {
            // 上一曲
            Column() {
              Image($r('sys.media.ohos_ic_public_play_last')).width(32).height(32).fillColor('#FF31C27C')
              Text('上一曲').fontSize(10).fontColor('#FF31C27C').margin({ top: 4 })
            }.onClick(() => this.prevSong()).disabled(!this.player.getPrevSong())

            Blank()

            // 停止
            Column() {
              Image($r('sys.media.ohos_ic_public_cancel')).width(32).height(32).fillColor('#B0B0B0')
              Text('停止').fontSize(10).fontColor('#B0B0B0').margin({ top: 4 })
            }.onClick(() => this.stop())

            Blank()

            // 播放/暂停
            Column() {
              Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
                .width(48).height(48).fillColor('#FF31C27C')
              Text(this.isPlaying ? '暂停' : '播放').fontSize(10).fontColor('#FF31C27C').margin({ top: 4 })
            }.onClick(() => this.togglePlay())

            Blank()

            // 下一曲
            Column() {
              Image($r('sys.media.ohos_ic_public_play_next')).width(32).height(32).fillColor('#FF31C27C')
              Text('下一曲').fontSize(10).fontColor('#FF31C27C').margin({ top: 4 })
            }.onClick(() => this.nextSong()).disabled(!this.player.getNextSong())
          }
          .width('100%').padding({ left: 24, right: 24 }).margin({ top: 20 })

          // ── 离线下载按钮 ──────────────────────────────────────────
          Row() {
            if (this.isDownloading) {
              // 下载中：进度条
              Column() {
                Progress({ value: this.downloadProgress, type: ProgressBarType.Line })
                  .width('90%').height(6).color('#FF31C27C').backgroundColor('#333333')
                  .borderRadius(3)
                Text(`下载中 ${this.downloadProgress}%`).fontSize(12).fontColor('#888888').margin({ top: 6 })
              }
              .width('100%').alignItems(HorizontalAlign.Center)
            } else if (this.isCached) {
              // 已缓存：显示"本地播放"按钮
              Button('已从本地播放')
                .width('90%').height(44)
                .fontSize(14).fontColor('#31C27C')
                .backgroundColor('#0A2E1F')
                .border({ width: 1, color: '#31C27C' })
                .borderRadius(12)
                .enabled(false)
            } else {
              // 可下载：展示下载按钮
              Button(this.currentSong.isVip ? 'VIP歌曲暂不可下载' : '⬇ 下载到本地（离线听）')
                .width('90%').height(44)
                .fontSize(14).fontColor(this.currentSong.isVip ? '#666666' : Color.White)
                .backgroundColor(this.currentSong.isVip ? '#1A1A1A' : '#FF31C27C')
                .borderRadius(12)
                .enabled(!this.currentSong.isVip)
                .onClick(() => this.downloadCurrentSong())
            }
          }
          .width('100%').margin({ top: 16 })

        } else {
          // 无歌曲
          Column() {
            Image($r('sys.media.ohos_ic_public_sound')).width(80).height(80).fillColor('#444444')
            Text('暂无播放歌曲').fontSize(16).fontColor('#666666').margin({ top: 16 })
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%').height('100%').backgroundColor('#000000')
  }
}
