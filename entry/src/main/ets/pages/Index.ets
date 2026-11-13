import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { Song } from '../model/Song';

/**
 * 首页 - 推荐/热门歌曲
 */
@Entry
@Component
struct Index {
  @State hotSongs: Song[] = [];
  @State isLoading: boolean = true;
  @State currentSong: Song | null = null;
  @State isPlaying: boolean = false;
  private player: AudioPlayer = AudioPlayer.getInstance();

  aboutToAppear(): void {
    this.loadHotSongs();
    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
      this.currentSong = this.player.getCurrentSong();
    };
  }

  /** 加载热门歌曲 */
  async loadHotSongs(): Promise<void> {
    this.isLoading = true;
    try {
      const result = await QQMusicApi.search('热门歌曲', 1, 10);
      this.hotSongs = result.songList;
    } catch (e) {
      promptAction.showToast({ message: '加载失败：' + (e as Error).message });
    } finally {
      this.isLoading = false;
    }
  }

  /** 播放歌曲 */
  async playSong(song: Song): Promise<void> {
    try {
      if (!song.playUrl) {
        promptAction.showToast({ message: '正在获取播放地址...' });
        song.playUrl = await QQMusicApi.getPlayUrl(song.songMid);
      }
      await this.player.play(song);
      this.currentSong = song;
    } catch (e) {
      promptAction.showToast({ message: '播放失败：' + (e as Error).message });
    }
  }

  /** 跳转到搜索页 */
  goSearch(): void {
    router.pushUrl({ url: 'pages/Search' });
  }

  /** 跳转到播放器页 */
  goPlayer(): void {
    if (this.currentSong) {
      router.pushUrl({ url: 'pages/Player' });
    } else {
      promptAction.showToast({ message: '请先选择一首歌曲' });
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('QQ音乐')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Blank()
        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .onClick(() => this.goSearch())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FF31C27C')

      // 内容区
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FF31C27C')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#B0B0B0')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.hotSongs, (song: Song) => {
            ListItem() {
              Row() {
                // 封面
                if (song.albumCoverUrl) {
                  Image(song.albumCoverUrl)
                    .width(48)
                    .height(48)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                } else {
                  Column() {
                    Image($r('sys.media.ohos_ic_public_sound'))
                      .width(28)
                      .height(28)
                      .fillColor('#666666')
                  }
                  .width(48)
                  .height(48)
                  .backgroundColor('#333333')
                  .borderRadius(8)
                  .justifyContent(FlexAlign.Center)
                }

                // 歌曲信息
                Column() {
                  Text(song.songName)
                    .fontSize(16)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(song.singerName)
                    .fontSize(12)
                    .fontColor('#B0B0B0')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .margin({ left: 12 })
                .alignItems(HorizontalAlign.Start)

                // 播放按钮
                Image($r('sys.media.ohos_ic_public_play'))
                  .width(28)
                  .height(28)
                  .fillColor('#FF31C27C')
                  .onClick(() => this.playSong(song))
              }
              .width('100%')
              .height(72)
              .padding({ left: 16, right: 16 })
              .backgroundColor('#1A1A1A')
              .borderRadius(12)
              .margin({ left: 8, right: 8 })
            }
          }, (song: Song) => song.songId.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: '#333333', startMargin: 76, endMargin: 16 })
      }

      // 底部正在播放栏
      if (this.currentSong) {
        Row() {
          if (this.currentSong.albumCoverUrl) {
            Image(this.currentSong.albumCoverUrl)
              .width(40)
              .height(40)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
          }
          Column() {
            Text(this.currentSong.songName)
              .fontSize(14)
              .fontColor(Color.White)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.currentSong.singerName)
              .fontSize(11)
              .fontColor('#B0B0B0')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .margin({ left: 10 })
          .alignItems(HorizontalAlign.Start)

          // 播放/暂停按钮
          Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .onClick(() => {
              if (this.isPlaying) {
                this.player.pause();
              } else {
                this.player.resume();
              }
            })
        }
        .width('100%')
        .height(64)
        .padding({ left: 12, right: 16 })
        .backgroundColor('#222222')
        .borderRadius({ topLeft: 16, topRight: 16 })
        .onClick(() => this.goPlayer())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
