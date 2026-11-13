import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { Song } from '../model/Song';

/**
 * 搜索页面
 */
@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State songList: Song[] = [];
  @State isLoading: boolean = false;
  @State hasSearched: boolean = false;
  private player: AudioPlayer = AudioPlayer.getInstance();

  /** 执行搜索 */
  async doSearch(): Promise<void> {
    if (!this.keyword.trim()) {
      promptAction.showToast({ message: '请输入搜索关键词' });
      return;
    }

    this.isLoading = true;
    this.hasSearched = true;
    try {
      const result = await QQMusicApi.search(this.keyword.trim(), 1, 30);
      this.songList = result.songList;
      if (this.songList.length === 0) {
        promptAction.showToast({ message: '未找到相关歌曲' });
      }
    } catch (e) {
      promptAction.showToast({ message: '搜索失败：' + (e as Error).message });
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
      router.pushUrl({ url: 'pages/Player' });
    } catch (e) {
      promptAction.showToast({ message: '播放失败：' + (e as Error).message });
    }
  }

  build() {
    Column() {
      // 搜索栏
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .onClick(() => router.back())
        TextInput({ placeholder: '搜索歌曲、歌手、专辑' })
          .layoutWeight(1)
          .height(40)
          .margin({ left: 8, right: 8 })
          .backgroundColor('#1A1A1A')
          .fontColor(Color.White)
          .placeholderColor('#666666')
          .borderRadius(20)
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => this.doSearch())
        Text('搜索')
          .fontSize(16)
          .fontColor('#FF31C27C')
          .onClick(() => this.doSearch())
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 16 })

      // 搜索结果
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color('#FF31C27C')
          Text('搜索中...')
            .fontSize(13)
            .fontColor('#B0B0B0')
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.hasSearched && this.songList.length > 0) {
        List({ space: 2 }) {
          ForEach(this.songList, (song: Song) => {
            ListItem() {
              Row() {
                Column() {
                  Text(song.songName)
                    .fontSize(15)
                    .fontColor(Color.White)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${song.singerName} - ${song.albumName}`)
                    .fontSize(12)
                    .fontColor('#B0B0B0')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Image($r('sys.media.ohos_ic_public_play'))
                  .width(26)
                  .height(26)
                  .fillColor('#FF31C27C')
                  .onClick(() => this.playSong(song))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor('#1A1A1A')
              .borderRadius(10)
              .margin({ left: 8, right: 8 })
              .onClick(() => this.playSong(song))
            }
          }, (song: Song) => song.songId.toString())
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column() {
          Image($r('sys.media.ohos_ic_public_search_filled'))
            .width(60)
            .height(60)
            .fillColor('#444444')
          Text('搜索你喜欢的音乐')
            .fontSize(14)
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
