import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
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
  private player: AudioPlayer = AudioPlayer.getInstance();

  aboutToAppear(): void {
    this.currentSong = this.player.getCurrentSong();
    this.isPlaying = this.player.getIsPlaying();

    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
    };

    this.player.onProgressChange = (position, dur) => {
      this.currentPosition = position;
      this.duration = dur;
    };

    this.player.onPlayComplete = () => {
      this.isPlaying = false;
    };
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

  build() {
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
        Blank()
          .width(24)
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
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ top: 20 })

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
          // 停止按钮
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(36)
            .height(36)
            .fillColor('#B0B0B0')
            .onClick(() => this.stop())

          Blank()

          // 上一曲（此处简化为停止，无播放列表功能）
          Image($r('sys.media.ohos_ic_public_play_last'))
            .width(40)
            .height(40)
            .fillColor('#666666')

          Blank()

          // 播放/暂停按钮
          Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(56)
            .height(56)
            .fillColor('#FF31C27C')
            .onClick(() => this.togglePlay())

          Blank()

          // 下一曲（此处简化，无播放列表功能）
          Image($r('sys.media.ohos_ic_public_play_next'))
            .width(40)
            .height(40)
            .fillColor('#666666')

          Blank()

          // 占位
          Image($r('sys.media.ohos_ic_public_play'))
            .width(36)
            .height(36)
            .fillColor('#00000000')
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
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
