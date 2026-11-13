import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { Song } from '../model/Song';

/**
 * 播放器页面
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
  private player: AudioPlayer = AudioPlayer.getInstance();

  aboutToAppear(): void {
    this.currentSong = this.player.getCurrentSong();
    this.isPlaying = this.player.getIsPlaying();

    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
      this.currentSong = this.player.getCurrentSong();
    };

    this.player.onProgressChange = (position, dur) => {
      this.currentPosition = position;
      this.duration = dur;
      this.updateLyricLine(position);
    };

    this.player.onPlayComplete = () => {
      this.isPlaying = false;
      // 自动播放下一首
      this.player.next().catch(() => {});
    };
  }

  /** 根据进度更新当前歌词行 */
  updateLyricLine(ms: number): void {
    if (!this.currentSong || !this.currentSong.lyricsText) return;
    const lines = this.currentSong.lyricsText.split('\n').filter(l => l.trim());
    // 简单估算：用时间比例
    if (this.duration <= 0) return;
    const ratio = ms / this.duration;
    const index = Math.floor(ratio * lines.length);
    this.currentLyricIndex = Math.min(index, lines.length - 1);
  }

  /** 播放/暂停切换 */
  togglePlay(): void {
    if (this.isPlaying) {
      this.player.pause();
    } else {
      this.player.resume();
    }
  }

  /** 停止 */
  stop(): void {
    this.player.stop();
  }

  /** 下一曲 */
  async nextSong(): Promise<void> {
    try {
      await this.player.next();
      // 获取下一首歌词
      const next = this.player.getNextSong();
      if (next && next.playUrl) {
        QQMusicApi.getLyrics(next.songMid).then((lyrics) => {
          next.lyricsText = lyrics;
        }).catch(() => {});
      }
    } catch (e) {
      promptAction.showToast({ message: '没有下一首' });
    }
  }

  /** 上一曲 */
  async prevSong(): Promise<void> {
    try {
      await this.player.prev();
      const prev = this.player.getPrevSong();
      if (prev && prev.playUrl) {
        QQMusicApi.getLyrics(prev.songMid).then((lyrics) => {
          prev.lyricsText = lyrics;
        }).catch(() => {});
      }
    } catch (e) {
      promptAction.showToast({ message: '没有上一首' });
    }
  }

  /** 拖动进度条 */
  onSliderChange(value: number): void {
    this.player.seekTo(value);
  }

  /** 格式化时间 */
  formatTime(ms: number): string {
    if (ms <= 0) return '00:00';
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${this.pad(minutes)}:${this.pad(seconds)}`;
  }

  private pad(num: number): string {
    return num < 10 ? '0' + num : num.toString();
  }

  /** 获取当前显示的歌词行 */
  getCurrentLyricLine(): string {
    if (!this.currentSong || !this.currentSong.lyricsText) return '';
    const lines = this.currentSong.lyricsText.split('\n').filter(l => l.trim());
    return lines[this.currentLyricIndex] || '';
  }

  build() {
    Scroll() {
      Column() {
        // 顶部栏
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
            .onClick(() => router.back())
          Text('正在播放')
            .fontSize(16)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button(this.showLyrics ? '歌词' : '关闭')
            .fontSize(12)
            .fontColor('#FF31C27C')
            .backgroundColor('#1A1A1A')
            .borderRadius(12)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => { this.showLyrics = !this.showLyrics; })
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })

        if (this.currentSong) {
          // 唱片封面
          Column() {
            if (this.currentSong.albumCoverUrl) {
              Image(this.currentSong.albumCoverUrl)
                .width(180)
                .height(180)
                .borderRadius(90)
                .objectFit(ImageFit.Cover)
            } else {
              Column() {
                Image($r('sys.media.ohos_ic_public_sound'))
                  .width(80)
                  .height(80)
                  .fillColor('#666666')
              }
              .width(180)
              .height(180)
              .borderRadius(90)
              .backgroundColor('#222222')
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .margin({ top: 20 })
          .justifyContent(FlexAlign.Center)

          // 歌曲信息
          Column() {
            Text(this.currentSong.songName)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
            Text(this.currentSong.singerName)
              .fontSize(14)
              .fontColor('#B0B0B0')
              .margin({ top: 8 })
            Text(this.currentSong.albumName)
              .fontSize(12)
              .fontColor('#808080')
              .margin({ top: 4 })
            if (this.currentSong.isVip) {
              Text('VIP歌曲')
                .fontSize(11)
                .fontColor('#FF9900')
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ top: 20 })

          // 歌词显示区
          if (this.showLyrics && this.currentSong.lyricsText) {
            Column() {
              ForEach(this.currentSong.lyricsText.split('\n').filter(l => l.trim()), (line: string, idx: number) => {
                Text(line)
                  .fontSize(idx === this.currentLyricIndex ? 14 : 12)
                  .fontColor(idx === this.currentLyricIndex ? '#FF31C27C' : '#555555')
                  .fontWeight(idx === this.currentLyricIndex ? FontWeight.Bold : FontWeight.Normal)
                  .margin({ top: 4, bottom: 4 })
              }, (line: string, idx: number) => idx.toString())
            }
            .width('100%')
            .padding({ left: 24, right: 24 })
            .margin({ top: 16 })
            .height(120)
            .overflow(Overflow.Scroll)
          } else if (this.showLyrics) {
            Text('暂无歌词')
              .fontSize(13)
              .fontColor('#555555')
              .margin({ top: 16 })
          }

          // 进度条
          Column() {
            Slider({
              value: this.currentPosition,
              min: 0,
              max: this.duration > 0 ? this.duration : 100,
              step: 1000
            })
              .width('100%')
              .blockColor('#FF31C27C')
              .trackColor('#333333')
              .selectedColor('#FF31C27C')
              .onChange((value: number) => this.onSliderChange(value))

            Row() {
              Text(this.formatTime(this.currentPosition))
                .fontSize(12)
                .fontColor('#B0B0B0')
              Blank()
              Text(this.formatTime(this.duration))
                .fontSize(12)
                .fontColor('#B0B0B0')
            }
            .width('100%')
            .margin({ top: 6 })
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ top: 24 })

          // 播放控制按钮
          Row() {
            // 上一曲
            Column() {
              Image($r('sys.media.ohos_ic_public_play_last'))
                .width(32)
                .height(32)
                .fillColor(this.player.getPrevSong() ? '#FF31C27C' : '#333333')
              Text('上一曲')
                .fontSize(10)
                .fontColor(this.player.getPrevSong() ? '#FF31C27C' : '#333333')
                .margin({ top: 4 })
            }
            .onClick(() => this.prevSong())
            .disabled(!this.player.getPrevSong())

            Blank()

            // 停止按钮
            Column() {
              Image($r('sys.media.ohos_ic_public_cancel'))
                .width(32)
                .height(32)
                .fillColor('#B0B0B0')
              Text('停止')
                .fontSize(10)
                .fontColor('#B0B0B0')
                .margin({ top: 4 })
            }
            .onClick(() => this.stop())

            Blank()

            // 播放/暂停按钮
            Column() {
              Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
                .width(48)
                .height(48)
                .fillColor('#FF31C27C')
              Text(this.isPlaying ? '暂停' : '播放')
                .fontSize(10)
                .fontColor('#FF31C27C')
                .margin({ top: 4 })
            }
            .onClick(() => this.togglePlay())

            Blank()

            // 下一曲
            Column() {
              Image($r('sys.media.ohos_ic_public_play_next'))
                .width(32)
                .height(32)
                .fillColor(this.player.getNextSong() ? '#FF31C27C' : '#333333')
              Text('下一曲')
                .fontSize(10)
                .fontColor(this.player.getNextSong() ? '#FF31C27C' : '#333333')
                .margin({ top: 4 })
            }
            .onClick(() => this.nextSong())
            .disabled(!this.player.getNextSong())
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ top: 20 })
        } else {
          Column() {
            Image($r('sys.media.ohos_ic_public_sound'))
              .width(80)
              .height(80)
              .fillColor('#444444')
            Text('暂无播放歌曲')
              .fontSize(16)
              .fontColor('#666666')
              .margin({ top: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
