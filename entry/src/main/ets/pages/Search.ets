import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { FavoritesManager } from '../utils/FavoritesManager';
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
  @State favoriteStatusMap: Record<string, boolean> = {};
  private player: AudioPlayer = AudioPlayer.getInstance();
  private favMgr: FavoritesManager = FavoritesManager.getInstance();

  /** 初始化收藏状态 */
  async aboutToAppear(): Promise<void> {
    await this.favMgr.init();
  }

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
      // 刷新收藏状态
      for (const song of this.songList) {
        this.favoriteStatusMap[song.songMid] = this.favMgr.isFavorite(song.songMid);
      }
      if (this.songList.length === 0) {
        promptAction.showToast({ message: '未找到相关歌曲' });
      }
    } catch (e) {
      promptAction.showToast({ message: '搜索失败：' + (e as Error).message });
    } finally {
      this.isLoading = false;
    }
  }

  /** 播放并加入队列 */
  async playSong(song: Song): Promise<void> {
    try {
      if (!song.playUrl) {
        if (song.isVip) {
          promptAction.showToast({ message: '该歌曲为VIP，暂无法播放' });
          return;
        }
        promptAction.showToast({ message: '正在获取播放地址...' });
        song.playUrl = await QQMusicApi.getPlayUrl(song.songMid);
        // 后台异步获取歌词
        QQMusicApi.getLyrics(song.songMid).then((lyrics) => {
          song.lyricsText = lyrics;
        }).catch(() => {});
      }
      // 重建队列为当前搜索结果列表，从当前歌曲开始
      this.player.playQueue(song);
      await this.player.play(song);
      router.pushUrl({ url: 'pages/Player' });
    } catch (e) {
      promptAction.showToast({ message: '播放失败：' + (e as Error).message });
    }
  }

  /** 切换收藏 */
  async toggleFavorite(song: Song): Promise<void> {
    const isFav = await this.favMgr.toggleFavorite(song.songMid);
    this.favoriteStatusMap[song.songMid] = isFav;
    if (isFav) {
      promptAction.showToast({ message: '已收藏' });
    } else {
      promptAction.showToast({ message: '已取消收藏' });
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

                // VIP标识
                if (song.isVip) {
                  Text('VIP')
                    .fontSize(10)
                    .fontColor('#FF9900')
                    .backgroundColor('#332200')
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .margin({ right: 6 })
                }

                // 收藏按钮
                Image(this.favoriteStatusMap[song.songMid] ? $r('sys.media.ohos_ic_public_heart_filled') : $r('sys.media.ohos_ic_public_heart'))
                  .width(24)
                  .height(24)
                  .fillColor(this.favoriteStatusMap[song.songMid] ? '#FF31C27C' : '#666666')
                  .onClick(() => this.toggleFavorite(song))
                  .margin({ right: 8 })

                // 播放按钮
                Image($r('sys.media.ohos_ic_public_play'))
                  .width(24)
                  .height(24)
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
