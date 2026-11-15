import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../AppState';
import { QQMusicApi } from '../utils/QQMusicApi';
import { AudioPlayer } from '../utils/AudioPlayer';
import { FavoritesManager } from '../utils/FavoritesManager';
import { LocalCacheManager } from '../utils/LocalCacheManager';
import { Song } from '../model/Song';

/**
 * 首页 — 热门推荐 / 离线歌曲 / 我的收藏（云端同步）
 *
 * Tab 说明：
 *   0 = 热门推荐（在线）
 *   1 = 离线缓存（本地已下载的歌曲）
 *   2 = 我的收藏（本地 + 可选云端同步）
 */
@Entry
@Component
struct Index {
  @State hotSongs: Song[] = [];
  @State isLoading: boolean = true;
  @State currentTab: number = 0; // 0热门 1离线 2收藏
  @State currentSong: Song | null = null;
  @State isPlaying: boolean = false;

  // 离线缓存列表
  @State offlineSongs: Song[] = [];
  @State downloadingMids: Set<string> = new Set();

  // 收藏相关
  @State favoriteSongs: Song[] = [];
  @State favoriteStatusMap: Record<string, boolean> = {};

  private appState: AppState = new AppState();
  private player: AudioPlayer = AudioPlayer.getInstance();
  private favMgr: FavoritesManager = FavoritesManager.getInstance();
  private cacheMgr: LocalCacheManager = LocalCacheManager.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.appState.refreshFromStorage();
    await this.favMgr.init();
    await this.cacheMgr.init();

    this.loadHotSongs();
    this.loadOfflineSongs();
    this.initFavorites();

    this.player.onPlayStateChange = (playing) => {
      this.isPlaying = playing;
      this.currentSong = this.player.getCurrentSong();
    };
  }

  // ── 数据加载 ────────────────────────────────────────────────────

  async initFavorites(): Promise<void> {
    const mids = this.favMgr.getFavoriteMids();
    if (mids.length === 0) {
      this.favoriteSongs = [];
      return;
    }
    // TODO: 登录后调用云端接口恢复完整歌曲信息，此处暂用本地 mid 列表
    // 方案A（简单）：直接将 mid 列表转为占位卡片，点击时再拉取详情
    this.favoriteSongs = mids.map(mid => new Song(
      0, mid, '加载中...', '未知歌手', '', '', 0
    ));
  }

  async loadOfflineSongs(): Promise<void> {
    // 扫描本地已缓存的 .m4a 文件并还原为 Song 对象
    // TODO: 接入持久化的缓存索引（Preferences存储 songMid→Song 映射）
    // 当前为空，等待后续实现
    this.offlineSongs = [];
  }

  async loadHotSongs(): Promise<void> {
    this.isLoading = true;
    try {
      const result = await QQMusicApi.search('热门歌曲', 1, 20);
      this.hotSongs = result.songList;
    } catch (e) {
      promptAction.showToast({ message: '加载失败：' + (e as Error).message });
    } finally {
      this.isLoading = false;
    }
  }

  // ── 播放控制 ────────────────────────────────────────────────────

  /**
   * 播放歌曲：优先使用本地缓存，无缓存则从网络获取播放地址
   */
  async playSong(song: Song, useOffline: boolean = false): Promise<void> {
    try {
      // 若指定使用离线且本地有缓存，直接用本地路径
      if (useOffline) {
        const cachedPath = this.cacheMgr.getCachedFilePath(song.songMid);
        if (cachedPath) {
          song.playUrl = `file://${cachedPath}`;
          await this.startPlaying(song);
          return;
        }
        promptAction.showToast({ message: '该歌曲暂无离线缓存，请先下载' });
        return;
      }

      if (!song.playUrl) {
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
      await this.startPlaying(song);
    } catch (e) {
      promptAction.showToast({ message: '播放失败：' + (e as Error).message });
    }
  }

  private async startPlaying(song: Song): Promise<void> {
    const list = this.currentTab === 0 ? this.hotSongs
      : this.currentTab === 1 ? this.offlineSongs
      : this.favoriteSongs;
    const idx = list.findIndex(s => s.songMid === song.songMid);
    this.player.playQueue(list[idx >= 0 ? idx : 0]);
    await this.player.play(song);
    this.currentSong = song;
  }

  /**
   * 下载歌曲到本地缓存（支持离线播放）
   */
  async downloadForOffline(song: Song): Promise<void> {
    if (this.downloadingMids.has(song.songMid)) return;
    if (!song.playUrl) {
      if (song.isVip) {
        promptAction.showToast({ message: 'VIP歌曲暂不支持下载' });
        return;
      }
      promptAction.showToast({ message: '正在获取播放地址...' });
      try {
        song.playUrl = await QQMusicApi.getPlayUrl(song.songMid);
      } catch (e) {
        promptAction.showToast({ message: '获取播放地址失败：' + (e as Error).message });
        return;
      }
    }
    if (!song.playUrl) return;

    this.downloadingMids.add(song.songMid);
    promptAction.showToast({ message: `正在下载：${song.songName}` });
    try {
      await this.cacheMgr.download(song.songMid, song.playUrl, (pct) => {
        // TODO: 更新单个歌曲的下拉进度条显示
      });
      promptAction.showToast({ message: `已下载到本地：${song.songName}` });
      // 加入离线列表
      this.offlineSongs.push(song);
    } catch (e) {
      promptAction.showToast({ message: '下载失败：' + (e as Error).message });
    } finally {
      this.downloadingMids.delete(song.songMid);
    }
  }

  /** 是否已缓存 */
  isCached(songMid: string): boolean {
    return this.cacheMgr.isCached(songMid);
  }

  // ── 导航 ────────────────────────────────────────────────────────

  goSearch(): void {
    router.pushUrl({ url: 'pages/Search' });
  }

  goPlayer(): void {
    if (this.currentSong) {
      router.pushUrl({ url: 'pages/Player' });
    } else {
      promptAction.showToast({ message: '请先选择一首歌曲' });
    }
  }

  goSettings(): void {
    router.pushUrl({ url: 'pages/UserSettingsPage' });
  }

  build() {
    Column() {
      // ── 顶部栏 ─────────────────────────────────────────────────
      Row() {
        Text('QQ音乐')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)

        // 设置按钮（登录入口）
        if (this.appState.isLoggedIn && this.appState.currentUser) {
          // 已登录：显示头像 + 设置入口
          Image(this.appState.currentUser.avatarUrl || '')
            .width(32)
            .height(32)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .onClick(() => this.goSettings())
            .margin({ right: 8 })
        } else {
          // 未登录：显示登录图标
          Image($r('sys.media.ohos_ic_public_person'))
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .onClick(() => this.goSettings())
            .margin({ right: 8 })
        }

        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
          .onClick(() => this.goSearch())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 12 })
      .backgroundColor('#FF31C27C')

      // ── Tab 切换 ────────────────────────────────────────────────
      Row() {
        this.buildTab('热门', 0)
        Divider().height(20).color('#CC9999').margin({ top: 8, bottom: 8 })
        this.buildTab('离线', 1)
        Divider().height(20).color('#CC9999').margin({ top: 8, bottom: 8 })
        this.buildTab('收藏', 2)
      }
      .width('100%')
      .backgroundColor('#E62A63')

      // ── 内容区 ──────────────────────────────────────────────────
      if (this.isLoading && this.currentTab === 0) {
        BuildLoading('加载中...')
      } else if (this.currentTab === 0) {
        BuildSongList(this.hotSongs, (song) => this.playSong(song),
          (song) => this.downloadForOffline(song),
          (mid) => this.isCached(mid),
          (song) => this.toggleFavorite(song))
      } else if (this.currentTab === 1) {
        if (this.offlineSongs.length > 0) {
          BuildSongList(this.offlineSongs, (song) => this.playSong(song, true),
            null, null, null)
        } else {
          BuildEmpty('暂无离线歌曲\n去「热门」或「搜索」页面点击下载按钮', '🎵')
        }
      } else {
        if (this.favoriteSongs.length > 0) {
          BuildSongList(this.favoriteSongs, (song) => this.playSong(song),
            null, null,
            (song) => this.toggleFavorite(song))
        } else {
          BuildEmpty(
            this.appState.isLoggedIn
              ? '收藏夹为空\n登录后将自动同步云端收藏'
              : '还没有收藏的歌曲\n去搜索页收藏吧',
            '❤️')
        }
      }

      // ── 底部播放条 ──────────────────────────────────────────────
      if (this.currentSong) {
        BuildMiniBar(this.currentSong, this.isPlaying,
          () => this.goPlayer(),
          () => this.player.pause(),
          () => this.player.resume(),
          () => this.player.prev().catch(() => {}),
          () => this.player.next().catch(() => {}))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  // ── 子组件 ──────────────────────────────────────────────────────

  buildTab(label: string, index: number): ComponentContent {
    return Text(label)
      .fontSize(15)
      .fontColor(this.currentTab === index ? Color.White : '#CC9999')
      .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .onClick(() => { this.currentTab = index; });
  }

  async toggleFavorite(song: Song): Promise<void> {
    const isFav = await this.favMgr.toggleFavorite(song.songMid);
    this.favoriteStatusMap[song.songMid] = isFav;
    if (isFav) {
      promptAction.showToast({ message: '已收藏' });
      // TODO: 若开启云端同步，调用云端接口保存
    } else {
      promptAction.showToast({ message: '已取消收藏' });
    }
  }
}

// ── 内联子组件（避免在 @Entry 中使用嵌套 struct 的编译问题）───────────

/** 通用加载中状态 */
@Component
struct BuildLoading {
  message: string = '加载中...';
  build() {
    Column() {
      LoadingProgress().width(40).height(40).color('#FF31C27C')
      Text(this.message).fontSize(14).fontColor('#B0B0B0').margin({ top: 12 })
    }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }
}

/** 通用空状态 */
@Component
struct BuildEmpty {
  message: string = '';
  emoji: string = '📂';
  build() {
    Column() {
      Text(this.emoji).fontSize(48).margin({ top: 40 })
      Text(this.message).fontSize(14).fontColor('#666666')
        .textAlign(TextAlign.Center).width('80%').markAsLineBreakWord(true)
    }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }
}

/**
 * 歌曲列表组件
 * @param songs           歌曲数组
 * @param onPlay          点击播放回调
 * @param onDownload      点击下载离线版回调（null = 不显示下载按钮）
 * @param isCachedFn      判断是否已缓存（null = 不显示缓存标识）
 * @param onToggleFav     点击收藏/取消收藏回调（null = 不显示收藏按钮）
 */
@Component
struct BuildSongList {
  songs: Song[] = [];
  onPlay: (song: Song) => void = () => {};
  onDownload: ((song: Song) => void) | null = null;
  isCachedFn: ((mid: string) => boolean) | null = null;
  onToggleFav: ((song: Song) => void) | null = null;

  build() {
    List({ space: 2 }) {
      ForEach(this.songs, (song: Song) => {
        ListItem() {
          Row() {
            // 封面
            if (song.albumCoverUrl) {
              Image(song.albumCoverUrl)
                .width(48).height(48).borderRadius(8).objectFit(ImageFit.Cover)
            } else {
              Column() {
                Image($r('sys.media.ohos_ic_public_sound'))
                  .width(28).height(28).fillColor('#666666')
              }
              .width(48).height(48).backgroundColor('#333333').borderRadius(8)
              .justifyContent(FlexAlign.Center)
            }

            // 信息
            Column() {
              Text(song.songName)
                .fontSize(16).fontColor(Color.White).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(song.singerName)
                .fontSize(12).fontColor('#B0B0B0').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 2 })
              // 标签行：VIP / 离线标识
              Row({ space: 4 }) {
                if (song.isVip) {
                  Text('VIP').fontSize(9).fontColor('#FF9900')
                    .backgroundColor('#332200').borderRadius(3)
                    .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                }
                if (this.isCachedFn && this.isCachedFn(song.songMid)) {
                  Text('本地').fontSize(9).fontColor('#31C27C')
                    .backgroundColor('#0A2E1F').borderRadius(3)
                    .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                }
              }.margin({ top: 3 })
            }
            .layoutWeight(1).margin({ left: 12 }).alignItems(HorizontalAlign.Start)

            // 操作按钮组
            Row({ space: 6 }) {
              // 收藏按钮
              if (this.onToggleFav) {
                Image(this.onToggleFav.toString().length > 0
                  ? $r('sys.media.ohos_ic_public_heart_filled')
                  : $r('sys.media.ohos_ic_public_heart'))
                  .width(22).height(22)
                  .fillColor('#666666')
                  .onClick(() => this.onToggleFav!(song))
              }
              // 离线下载按钮
              if (this.onDownload) {
                Image($r('sys.media.ohos_ic_public_download'))
                  .width(22).height(22)
                  .fillColor(this.isCachedFn && this.isCachedFn(song.songMid) ? '#FF31C27C' : '#666666')
                  .onClick(() => !song.isVip && this.onDownload!(song))
              }
              // 播放按钮
              Image($r('sys.media.ohos_ic_public_play'))
                .width(26).height(26).fillColor('#FF31C27C')
                .onClick(() => this.onPlay(song))
            }
          }
          .width('100%').height(72)
          .padding({ left: 16, right: 12 })
          .backgroundColor('#1A1A1A').borderRadius(12)
          .margin({ left: 8, right: 8 })
        }
      }, (song: Song) => song.songId.toString())
    }
    .width('100%').layoutWeight(1)
    .divider({ strokeWidth: 1, color: '#333333', startMargin: 76, endMargin: 16 })
  }
}

/** 底部迷你播放条 */
@Component
struct BuildMiniBar {
  song: Song;
  isPlaying: boolean;
  onGoPlayer: () => void = () => {};
  onPause: () => void = () => {};
  onResume: () => void = () => {};
  onPrev: () => void = () => {};
  onNext: () => void = () => {};

  build() {
    Row() {
      if (this.song.albumCoverUrl) {
        Image(this.song.albumCoverUrl)
          .width(40).height(40).borderRadius(6).objectFit(ImageFit.Cover)
      }
      Column() {
        Text(this.song.songName).fontSize(14).fontColor(Color.White).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.song.singerName).fontSize(11).fontColor('#B0B0B0').maxLines(1)
          .margin({ top: 1 })
      }
      .layoutWeight(1).margin({ left: 10 }).alignItems(HorizontalAlign.Start)

      Image($r('sys.media.ohos_ic_public_play_last'))
        .width(22).height(22).fillColor(Color.White)
        .margin({ right: 6 }).onClick(() => this.onPrev())

      Image(this.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
        .width(26).height(26).fillColor(Color.White)
        .margin({ right: 6 }).onClick(() => this.isPlaying ? this.onPause() : this.onResume())

      Image($r('sys.media.ohos_ic_public_play_next'))
        .width(22).height(22).fillColor(Color.White)
        .margin({ right: 8 }).onClick(() => this.onNext())
    }
    .width('100%').height(64).padding({ left: 12, right: 16 })
    .backgroundColor('#222222').borderRadius({ topLeft: 16, topRight: 16 })
    .onClick(() => this.onGoPlayer())
  }
}
