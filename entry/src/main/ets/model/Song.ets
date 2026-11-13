/**
 * 歌曲数据模型
 */
export class Song {
  /** 歌曲ID */
  songId: number;
  /** 歌曲mid（用于获取播放地址） */
  songMid: string;
  /** 歌曲名称 */
  songName: string;
  /** 歌手名称 */
  singerName: string;
  /** 专辑名称 */
  albumName: string;
  /** 专辑封面URL */
  albumCoverUrl: string;
  /** 播放时长（秒） */
  duration: number;
  /** 播放地址 */
  playUrl: string = '';
  /** 歌词URL */
  lrcUrl: string = '';
  /** 歌词文本 */
  lyricsText: string = '';
  /** 是否VIP歌曲 */
  isVip: boolean = false;

  constructor(songId: number, songMid: string, songName: string, singerName: string,
    albumName: string, albumCoverUrl: string, duration: number) {
    this.songId = songId;
    this.songMid = songMid;
    this.songName = songName;
    this.singerName = singerName;
    this.albumName = albumName;
    this.albumCoverUrl = albumCoverUrl;
    this.duration = duration;
  }
}

/**
 * 搜索结果
 */
export class SearchResult {
  /** 歌曲列表 */
  songList: Song[];
  /** 总数 */
  total: number;
  /** 当前页码 */
  page: number;

  constructor(songList: Song[], total: number, page: number) {
    this.songList = songList;
    this.total = total;
    this.page = page;
  }
}
