import { http } from '@kit.NetworkKit';
import { Song, SearchResult } from '../model/Song';

/**
 * 搜索结果中的单条歌曲信息
 */
interface SearchSongItem {
  songid: number;
  songmid: string;
  songname: string;
  singer: Array<Record<string, string>>;
  albumname: string;
  albummid: string;
  interval: number;
}

/**
 * 搜索接口返回 - song字段
 */
interface SearchSongData {
  list: SearchSongItem[];
  totalnum: number;
}

/**
 * 搜索接口返回 - data字段
 */
interface SearchData {
  song: SearchSongData;
}

/**
 * 搜索接口返回结构
 */
interface SearchResponse {
  code: number;
  data: SearchData;
}

/**
 * vkey接口返回 - 单条item
 */
interface VkeyItem {
  vkey: string;
}

/**
 * vkey接口返回 - data字段
 */
interface VkeyData {
  items: VkeyItem[];
}

/**
 * vkey接口返回结构
 */
interface VkeyResponse {
  code: number;
  data: VkeyData;
}

/**
 * 歌词接口返回 - 单条item
 */
interface LrcItem {
  lrc: string;
}

/**
 * 歌词接口返回结构
 */
interface LrcResponse {
  code: number;
  data: LrcItem;
}

/**
 * QQ音乐Web API封装
 * 说明：使用QQ音乐网页端公开接口，仅用于学习研究，版权归腾讯所有
 */
export class QQMusicApi {
  private static readonly SEARCH_URL = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';
  private static readonly VKEY_URL = 'https://c.y.qq.com/base/fcgi-bin/fcg_music_express_mobile3.fcg';
  private static readonly LRC_URL = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg';
  private static readonly PLAY_HOST = 'https://dl.stream.qqmusic.qq.com';
  private static readonly COVER_HOST = 'https://y.qq.com/music/photo_new';

  /** 随机生成guid（QQ音乐接口要求） */
  private static generateGuid(): string {
    return Math.floor(Math.random() * 10000000000).toString();
  }

  /**
   * 搜索歌曲
   * @param keyword 关键词
   * @param page 页码（从1开始）
   * @param pageSize 每页数量
   */
  static async search(keyword: string, page: number = 1, pageSize: number = 20): Promise<SearchResult> {
    const url = `${QQMusicApi.SEARCH_URL}?w=${encodeURIComponent(keyword)}&format=json&p=${page}&n=${pageSize}`;
    const json = await QQMusicApi.httpGetJson(url) as SearchResponse;

    const code: number = json.code;
    if (code !== 0) {
      throw new Error(`搜索失败，错误码：${code}`);
    }

    const data = json.data;
    const song = data.song;
    const list = song.list || [];
    const total: number = song.totalnum || 0;

    const songList: Song[] = list.map((item: SearchSongItem) => {
      const songId: number = item.songid;
      const songMid: string = item.songmid;
      const songName: string = item.songname;
      const singerArr = item.singer;
      const singerName: string = singerArr ? singerArr.map((s) => s.name).join('/') : '未知歌手';
      const albumName: string = item.albumname || '未知专辑';
      const albumMid: string = item.albummid;
      const albumCoverUrl: string = albumMid ? `${QQMusicApi.COVER_HOST}/T002R300x300M000${albumMid}.jpg` : '';
      const duration: number = item.interval || 0;
      // interval单位为秒；VIP歌曲interval字段可能为null或异常值，通过检查interval推断
      const isVip: boolean = !songMid || item.interval === null || item.interval === undefined;

      return new Song(songId, songMid, songName, singerName, albumName, albumCoverUrl, duration, '', '', isVip);
    });

    return new SearchResult(songList, total, page);
  }

  /**
   * 获取歌曲播放地址
   * @param songMid 歌曲mid
   */
  static async getPlayUrl(songMid: string): Promise<string> {
    const guid = QQMusicApi.generateGuid();
    const filename = `C400${songMid}.m4a`;
    const url = `${QQMusicApi.VKEY_URL}?g_tk=0&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0&cid=205361747&uin=0&songmid=${songMid}&filename=${filename}&guid=${guid}`;

    const json = await QQMusicApi.httpGetJson(url) as VkeyResponse;
    const data = json.data;
    const items = data.items || [];

    if (items.length === 0) {
      throw new Error('未获取到播放地址');
    }

    const vkey: string = items[0].vkey;
    if (!vkey) {
      throw new Error('获取vkey失败，该歌曲可能需要付费或无版权');
    }

    return `${QQMusicApi.PLAY_HOST}/${filename}?vkey=${vkey}&guid=${guid}&uin=0&fromtag=66`;
  }

  /**
   * 批量获取歌曲播放地址
   */
  static async getPlayUrls(songMids: string[]): Promise<Map<string, string>> {
    const result = new Map<string, string>();
    for (const mid of songMids) {
      try {
        const url = await QQMusicApi.getPlayUrl(mid);
        result.set(mid, url);
      } catch (e) {
        result.set(mid, '');
      }
    }
    return result;
  }

  /**
   * 获取歌词文本
   * @param songMid 歌曲mid
   */
  static async getLyrics(songMid: string): Promise<string> {
    const url = `${QQMusicApi.LRC_URL}?songmid=${songMid}&jsonpCallback=&format=json`;

    const json = await QQMusicApi.httpGetJson(url) as LrcResponse;
    const data = json.data;
    const lrc = data.lrc || '';
    if (!lrc) {
      return '';
    }
    // 解析歌词文本，去掉时间标签
    const lines = lrc.split('\n');
    const cleanLines = lines.filter((line: string) => line.trim() && !line.includes('['));
    return cleanLines.join('\n');
  }

  /**
   * 发送HTTP GET请求并解析JSON
   */
  private static async httpGetJson(url: string): Promise<Object> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          'Referer': 'https://y.qq.com/'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      });

      if (response.responseCode !== 200) {
        throw new Error(`HTTP请求失败，状态码：${response.responseCode}`);
      }

      let body: string = response.result as string;
      // 部分接口返回JSONP格式，需要去掉callback包裹
      if (body.startsWith('callback(') && body.endsWith(')')) {
        body = body.substring(9, body.length - 1);
      } else if (body.startsWith('(') && body.endsWith(')')) {
        body = body.substring(1, body.length - 1);
      }

      return JSON.parse(body) as Object;
    } finally {
      httpRequest.destroy();
    }
  }
}
