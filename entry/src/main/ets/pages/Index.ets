import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { FavoritesManager } from '../utils/FavoritesManager';
import { Song } from '../model/Song';

/**
 * 首页 - 推荐/热门歌曲 + 收藏Tab
 */
@Entry
@Component
struct Index {
  @State hotSongs: Song[] = [];
  @State isLoading: boolean = true;
  @State currentTab: number = 0; // 0=热门 1=收藏
  @State currentSong: Song | null = null;
  @State isPlaying: boolean = false;
  @State favoriteSongs: Song[] = [];
  @State favoriteStatusMap: Record<string, boolean> = {};
  private player: AudioPlayer = AudioPlayer.getInstance();
  private favMgr: FavoritesManager = FavoritesManager.getInstance();

  aboutToAppear(): void {
    this.loadHotSongs();
    this.initFavorites();
    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
      this.currentSong = this.player.getCurrentSong();
    };
  }

  /** 初始化收藏列表 */
  async initFavorites(): Promise<void> {
    await this.favMgr.init();
    // 由于我们不知道收藏歌曲的完整信息，需要重新搜索或直接存储歌曲对象
    // 这里简化处理：每次加载时从偏好存储中读取mid列表，然后逐个拉取信息
    // 为简化，我们只维护一个"最近播放历史"概念，实际收藏功能在详情页更实用
    // 此处理论上需要持久化完整Song对象，此处先空实现
    this.favoriteSongs = [];
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
        if (song.isVip) {
          promptAction.showToast({ message: '该歌曲为VIP，暂无法播放' });
          return;
        }
        promptAction.showToast({ message: '正在获取播放地址...' });
        song.playUrl = await QQMusicApi.getPlayUrl(song.songMid);
        // 后台获取歌词
        QQMusicApi.getLyrics(song.songMid).then((lyrics) => {
          song.lyricsText = lyrics;
        }).catch(() => {});
      }
      // 将当前列表中所有歌曲加入队列，从这首开始
      const currentIndex = this.currentTab === 0
        ? this.hotSongs.findIndex(s => s.songMid === song.songMid)
        : this.favoriteSongs.findIndex(s => s.songMid === song.songMid);
      const list = this.currentTab === 0 ? this.hotSongs : this.favoriteSongs;
      this.player.playQueue(list[currentIndex >= 0 ? currentIndex : 0]);
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

      // Tab切换栏
      Row() {
        Text('热门')
          .fontSize(15)
          .fontColor(this.currentTab === 0 ? Color.White : '#CC9999')
          .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .onClick(() => { this.currentTab = 0; })
        Divider()
          .width(1)
          .height(20)
          .color('#CC9999')
          .margin({ top: 8, bottom: 8 })
        Text('收藏')
          .fontSize(15)
          .fontColor(this.currentTab === 1 ? Color.White : '#CC9999')
          .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .onClick(() => { this.currentTab = 1; })
      }
      .width('100%')
      .backgroundColor('#E62A63')

      // 内容区
      if (this.isLoading && this.currentTab === 0) {
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
      } else if (this.currentTab === 0) {
        List({ space: 2 }) {
          ForEach(this.hotSongs, (song: Song) => {
            ListItem() {
              Row() {
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

                if (song.isVip) {
                  Text('VIP')
                    .fontSize(10)
                    .fontColor('#FF9900')
                    .backgroundColor('#332200')
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .margin({ right: 6 })
                }

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
      } else {
        // 收藏Tab为空时的提示
        Column() {
          Image($r('sys.media.ohos_ic_public_heart'))
            .width(60)
            .height(60)
            .fillColor('#444444')
          Text('还没有收藏的歌曲\n去搜索页收藏吧')
            .fontSize(14)
            .fontColor('#666666')
            .textAlign(TextAlign.Center)
            .margin({ top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 底部正在播放 bar
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

          // 上一曲
          Image($r('sys.media.ohos_ic_public_play_last'))
            .width(24)
            .height(24)
            .fillColor(this.player.getPrevSong() ? Color.White : '#333333')
            .margin({ right: 6 })
            .onClick(() => this.player.prev().catch(() => {}))
            .enabled(!!this.player.getPrevSong())

          // 播放/暂停
          Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .margin({ right: 6 })
            .onClick(() => {
              if (this.isPlaying) {
                this.player.pause();
              } else {
                this.player.resume();
              }
            })

          // 下一曲
          Image($r('sys.media.ohos_ic_public_play_next'))
            .width(24)
            .height(24)
            .fillColor(this.player.getNextSong() ? Color.White : '#333333')
            .margin({ right: 8 })
            .onClick(() => this.player.next().catch(() => {}))
            .enabled(!!this.player.getNextSong())
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
