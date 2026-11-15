import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../AppState';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { LocalCacheManager } from '../utils/LocalCacheManager';
import { FavoritesManager } from '../utils/FavoritesManager';
import { Song } from '../model/Song';

/**
 * 搜索页面 — 支持在线播放 / 离线下载 / 收藏
 */
@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State songList: Song[] = [];
  @State isLoading: boolean = false;
  @State hasSearched: boolean = false;
  @State favoriteStatusMap: Record<string, boolean> = {};
  @State downloadingMids: Set<string> = new Set();

  private appState: AppState = new AppState();
  private player: AudioPlayer = AudioPlayer.getInstance();
  private cacheMgr: LocalCacheManager = LocalCacheManager.getInstance();
  private favMgr: FavoritesManager = FavoritesManager.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.favMgr.init();
  }

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
      // 刷新收藏状态 + 缓存状态
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

  /** 播放（优先使用本地缓存） */
  async playSong(song: Song): Promise<void> {
    try {
      const cachedPath = this.cacheMgr.getCachedFilePath(song.songMid);
      if (cachedPath) {
        song.playUrl = `file://${cachedPath}`;
      } else if (!song.playUrl) {
        if (song.isVip) {
          promptAction.showToast({ message: '该歌曲为VIP，暂无法播放' });
          return;
        }
        promptAction.showToast({ message: '正在获取播放地址...' });
        song.playUrl = await QQMusicApi.getPlayUrl(song.songMid);
        QQMusicApi.getLyrics(song.songMid).then((lyrics) => {
          song.lyricsText = lyrics;
        }).catch(() => {});
      }
      this.player.playQueue(song);
      await this.player.play(song);
      router.pushUrl({ url: 'pages/Player' });
    } catch (e) {
      promptAction.showToast({ message: '播放失败：' + (e as Error).message });
    }
  }

  /** 切换收藏状态 */
  async toggleFavorite(song: Song): Promise<void> {
    const isFav = await this.favMgr.toggleFavorite(song.songMid);
    this.favoriteStatusMap[song.songMid] = isFav;
    promptAction.showToast({ message: isFav ? '已收藏' : '已取消收藏' });
    // TODO: 若用户在设置中开启云端同步，此处调用云接口保存
  }

  /** 下载歌曲到本地 */
  async downloadForOffline(song: Song): Promise<void> {
    if (this.downloadingMids.has(song.songMid)) return;
    if (song.isVip) {
      promptAction.showToast({ message: 'VIP歌曲暂不支持离线下载' });
      return;
    }
    if (!song.playUrl) {
      promptAction.showToast({ message: '请先点击播放按钮获取地址后再下载' });
      return;
    }
    this.downloadingMids.add(song.songMid);
    promptAction.showToast({ message: `正在下载：${song.songName}` });
    try {
      await this.cacheMgr.download(song.songMid, song.playUrl, () => {});
      promptAction.showToast({ message: `✅ ${song.songName} 已保存到本地` });
    } catch (e) {
      promptAction.showToast({ message: '下载失败：' + (e as Error).message });
    } finally {
      this.downloadingMids.delete(song.songMid);
    }
  }

  build() {
    Column() {
      // ── 搜索栏 ──────────────────────────────────────────────────
      Row() {
        Image($r('sys.media.ohos_ic_public_arrow_left'))
          .width(24).height(24).fillColor(Color.White)
          .onClick(() => router.back())
        TextInput({ placeholder: '搜索歌曲、歌手、专辑' })
          .layoutWeight(1).height(40).margin({ left: 8, right: 8 })
          .backgroundColor('#1A1A1A').fontColor(Color.White)
          .placeholderColor('#666666').borderRadius(20)
          .onChange((v: string) => { this.keyword = v; })
          .onSubmit(() => this.doSearch())
        Text('搜索').fontSize(16).fontColor('#FF31C27C')
          .onClick(() => this.doSearch())
      }
      .width('100%').height(56).padding({ left: 12, right: 16 })

      // ── 搜索结果 ────────────────────────────────────────────────
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(36).height(36).color('#FF31C27C')
          Text('搜索中...').fontSize(13).fontColor('#B0B0B0').margin({ top: 10 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.hasSearched && this.songList.length > 0) {
        List({ space: 2 }) {
          ForEach(this.songList, (song: Song) => {
            ListItem() {
              Row() {
                // 封面
                if (song.albumCoverUrl) {
                  Image(song.albumCoverUrl).width(48).height(48).borderRadius(8).objectFit(ImageFit.Cover)
                } else {
                  Column() {
                    Image($r('sys.media.ohos_ic_public_sound')).width(28).height(28).fillColor('#666666')
                  }
                  .width(48).height(48).backgroundColor('#333333').borderRadius(8)
                  .justifyContent(FlexAlign.Center)
                }

                // 信息
                Column() {
                  Text(song.songName).fontSize(15).fontColor(Color.White).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${song.singerName} - ${song.albumName}`)
                    .fontSize(12).fontColor('#B0B0B0').maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 2 })
                  Row({ space: 4 }) {
                    if (song.isVip) {
                      Text('VIP').fontSize(9).fontColor('#FF9900').backgroundColor('#332200')
                        .borderRadius(3).padding({ left: 3, right: 3, top: 1, bottom: 1 })
                    }
                    if (this.cacheMgr.isCached(song.songMid)) {
                      Text('本地').fontSize(9).fontColor('#31C27C').backgroundColor('#0A2E1F')
                        .borderRadius(3).padding({ left: 3, right: 3, top: 1, bottom: 1 })
                    }
                  }.margin({ top: 3 })
                }
                .layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)

                // 操作按钮
                Row({ space: 6 }) {
                  // 收藏
                  Image(this.favoriteStatusMap[song.songMid]
                    ? $r('sys.media.ohos_ic_public_heart_filled')
                    : $r('sys.media.ohos_ic_public_heart'))
                    .width(22).height(22)
                    .fillColor(this.favoriteStatusMap[song.songMid] ? '#FF31C27C' : '#666666')
                    .onClick(() => this.toggleFavorite(song))

                  // 下载
                  if (!song.isVip) {
                    Image(this.downloadingMids.has(song.songMid)
                      ? $r('sys.media.ohos_ic_public_pause')
                      : $r('sys.media.ohos_ic_public_download'))
                      .width(22).height(22)
                      .fillColor(this.downloadingMids.has(song.songMid) ? '#FF9900' : '#666666')
                      .onClick(() => !this.downloadingMids.has(song.songMid) && this.downloadForOffline(song))
                  }

                  // 播放
                  Image($r('sys.media.ohos_ic_public_play'))
                    .width(24).height(24).fillColor('#FF31C27C')
                    .onClick(() => this.playSong(song))
                }
              }
              .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor('#1A1A1A').borderRadius(10)
              .margin({ left: 8, right: 8 })
              .onClick(() => this.playSong(song))
            }
          }, (song: Song) => song.songId.toString())
        }
        .width('100%').layoutWeight(1)
      } else {
        BuildEmpty('搜索你喜欢的音乐\n支持在线播放 & 离线缓存', '🔍')
      }
    }
    .width('100%').height('100%').backgroundColor('#000000')
  }
}

@Component
struct BuildEmpty {
  message: string = '';
  emoji: string = '🔍';
  build() {
    Column() {
      Text(this.emoji).fontSize(48).margin({ top: 60 })
      Text(this.message).fontSize(14).fontColor('#666666').textAlign(TextAlign.Center)
        .width('80%').markAsLineBreakWord(true).margin({ top: 16 })
    }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }
}
