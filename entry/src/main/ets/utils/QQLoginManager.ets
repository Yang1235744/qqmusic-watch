/**
 * QQ 登录管理器
 *
 * 支持的登录方式（框架占位，按优先级依次尝试）：
 *   1. QR Code 扫码登录（手机端打开 https://y.qq.com → 扫一扫授权）
 *   2. 账号密码登录（输入 QQ 号 + 密码）
 *   3. Web OAuth 跳转登录（跳转到 QQ 官方 OAuth 页面完成授权）
 *
 * 数据来源参考（红米 Watch 5 QQ音乐版）：
 *   - 红米 Watch 5 使用「手表端唤起手机 QQ → 手机端确认授权」流程
 *   - 本实现预留了同样的接口签名，方便后续对接真实 SDK
 *
 * TODO（待接入真实 QQ SDK 后替换下列空实现）：
 *   - loginWithQRCode()  → 调用 harmony-qq-sdk 或WebView加载 QQ开放平台 OAuth URL
 *   - loginWithPassword() → 调用腾讯开放平台 token 接口换取 access_token
 *   - refreshToken()      → 使用 refresh_token 换取新 access_token
 */

import { preferences } from '@kit.ArkData';

// ── 数据类型定义 ───────────────────────────────────────────────────

export interface QQLoginUser {
  openId: string;
  qqNumber: string;
  nickName: string;
  avatarUrl: string;
  /** token 有效期（秒），通常为 7776000（90天） */
  expiresIn: number;
}

export interface QQAuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  scope: string;
}

// QQ 开放平台配置（正式环境请替换为自己在https://open.qq.com注册的 AppID）
const QQ_CLIENT_ID = '101958944';   // TODO: 替换为你的 QQ互联 AppID
const QQ_REDIRECT_URI = 'https://y.qq.com/portal/wx_redirect.html';  // TODO: 替换为你的回调域名
const QQ_AUTH_URL = 'https://graph.qq.com/oauth2.0/authorize';
const QQ_TOKEN_URL = 'https://graph.qq.com/oauth2.0/token';
const QQ_OPENID_URL = 'https://graph.qq.com/oauth2.0/me';
const QQ_USERINFO_URL = 'https://graph.qq.com/user/get_user_info';

// ── 管理器实现 ─────────────────────────────────────────────────────

export class QQLoginManager {
  private static instance: QQLoginManager | null = null;
  private static readonly PREFS_NAME = 'qq_login_prefs';
  private static readonly KEY_TOKEN = 'qq_access_token';
  private static readonly KEY_REFRESH = 'qq_refresh_token';
  private static readonly KEY_EXPIRES = 'qq_expires_in';
  private static readonly KEY_USER = 'qq_user_info';

  private store: preferences.Preferences | null = null;
  private tokens: QQAuthTokens | null = null;
  private user: QQLoginUser | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): QQLoginManager {
    if (!QQLoginManager.instance) {
      QQLoginManager.instance = new QQLoginManager();
    }
    return QQLoginManager.instance;
  }

  get isLoggedIn(): boolean {
    return !!(this.tokens && this.tokens.accessToken);
  }

  get currentUser(): QQLoginUser | null {
    return this.user;
  }

  /** 初始化：从持久化存储恢复登录态 */
  async init(): Promise<void> {
    if (this.initialized) return;
    try {
      this.store = await preferences.getPreferences(QQLoginManager.PREFS_NAME);
      const token = (await this.store!.get(QQLoginManager.KEY_TOKEN, '') as string) ?? '';
      const refresh = (await this.store!.get(QQLoginManager.KEY_REFRESH, '') as string) ?? '';
      const expires = parseInt(await this.store!.get(QQLoginManager.KEY_EXPIRES, '0') as string, 10);
      const userRaw = (await this.store!.get(QQLoginManager.KEY_USER, '') as string) ?? '';

      if (token && Date.now() / 1000 < expires) {
        this.tokens = { accessToken: token, refreshToken: refresh, expiresIn: expires, scope: 'basic' };
        if (userRaw) {
          this.user = JSON.parse(userRaw) as QQLoginUser;
        }
      }
    } catch (e) {
      console.error('[QQLogin] 初始化失败:', e);
    }
    this.initialized = true;
  }

  // ── 登录入口（三选一，按场景选用）─────────────────────────────

  /**
   * 方式一：二维码扫码登录
   * TODO: 接入 harmony-qq-sdk 或 WebView，打开以下 URL 展示二维码：
   *   https://graph.qq.com/oauth2.0/show?which=Login&display=pc&client_id=QQ_CLIENT_ID&redirect_uri=QQ_REDIRECT_URI&response_type=code&scope=get_user_info
   * 扫码成功后从 redirect_uri 参数中提取 code，调用 loginWithCode()。
   */
  async loginWithQRCode(): Promise<void> {
    // TODO: 打开 WebView 加载 QQ OAuth 二维码页面，等待扫码回调
    // 参考实现（伪代码）：
    //   webviewController.loadUrl(`${QQ_AUTH_URL}?client_id=${QQ_CLIENT_ID}&redirect_uri=${encodeURIComponent(QQ_REDIRECT_URI)}&response_type=code&scope=get_user_info`)
    //   // 在 onPageBegin 解析 callback URL 提取 code
    //   this.loginWithCode(extractedCode)
    console.warn('[QQLogin] loginWithQRCode 尚未接入真实SDK，仅保留框架');
    throw new Error('loginWithQRCode: 需要接入QQ开放平台SDK');
  }

  /**
   * 方式二：账号密码直接登录（不推荐，易触发风控）
   * TODO: 调用 https://graph.qq.com/oauth2.0/login_with_ex.token 或握手流程
   */
  async loginWithPassword(qqNumber: string, password: string): Promise<void> {
    // TODO: 接入 QQ 统一登录 SDK（harmony-qq-sdk）
    console.warn('[QQLogin] loginWithPassword 尚未接入真实SDK，仅保留框架');
    throw new Error('loginWithPassword: 需要接入QQ开放平台SDK');
  }

  /**
   * 方式三：通过授权码登录（扫码回调后调用）
   * @param authCode 从 redirect_uri?code=xxx 中提取的 authorization code
   */
  async loginWithCode(authCode: string): Promise<QQLoginUser> {
    const tokens = await this.fetchAccessToken(authCode);
    const openId = await this.fetchOpenId(tokens.accessToken);
    const user = await this.fetchUserInfo(openId, tokens.accessToken);

    this.tokens = tokens;
    this.user = user;
    await this.persistTokens();
    return user;
  }

  /**
   * 刷新 Token（accessToken 过期时用 refreshToken 换取新 token）
   */
  async refreshToken(): Promise<QQAuthTokens> {
    if (!this.tokens?.refreshToken) {
      throw new Error('没有可用的 refresh_token，请重新登录');
    }
    const newTokens = await this.exchangeRefreshToken(this.tokens.refreshToken);
    this.tokens = newTokens;
    await this.persistTokens();
    return newTokens;
  }

  /**
   * 退出登录（清除本地 token 和用户信息）
   */
  async logout(): Promise<void> {
    this.tokens = null;
    this.user = null;
    if (this.store) {
      await this.store.delete(QQLoginManager.KEY_TOKEN);
      await this.store.delete(QQLoginManager.KEY_REFRESH);
      await this.store.delete(QQLoginManager.KEY_EXPIRES);
      await this.store.delete(QQLoginManager.KEY_USER);
      await this.store.flush();
    }
    console.info('[QQLogin] 已退出登录');
  }

  // ── 内部 API 调用（TODO: 真实环境需替换为对应 SDK 调用）────────

  private async fetchAccessToken(code: string): Promise<QQAuthTokens> {
    // TODO: 实际实现请调用 https://graph.qq.com/oauth2.0/token
    //   ?grant_type=authorization_code&client_id=...&redirect_uri=...&code=...&state=...
    throw new Error('fetchAccessToken: 需要接入QQ开放平台API');
  }

  private async fetchOpenId(accessToken: string): Promise<string> {
    // TODO: GET https://graph.qq.com/oauth2.0/me?access_token=XXX
    //   返回 {"openid":"xxx","client_id":"xxx"}
    throw new Error('fetchOpenId: 需要接入QQ开放平台API');
  }

  private async fetchUserInfo(openId: string, accessToken: string): Promise<QQLoginUser> {
    // TODO: GET https://graph.qq.com/user/get_user_info?access_token=XXX&openid=XXX&format=json
    throw new Error('fetchUserInfo: 需要接入QQ开放平台API');
  }

  private async exchangeRefreshToken(refreshToken: string): Promise<QQAuthTokens> {
    // TODO: POST https://graph.qq.com/oauth2.0/token
    //   ?grant_type=refresh_token&client_id=...&refresh_token=...
    throw new Error('exchangeRefreshToken: 需要接入QQ开放平台API');
  }

  private async persistTokens(): Promise<void> {
    if (!this.store || !this.tokens || !this.user) return;
    await this.store.put(QQLoginManager.KEY_TOKEN, this.tokens.accessToken);
    await this.store.put(QQLoginManager.KEY_REFRESH, this.tokens.refreshToken);
    await this.store.put(QQLoginManager.KEY_EXPIRES, (Date.now() / 1000 + this.tokens.expiresIn).toString());
    await this.store.put(QQLoginManager.KEY_USER, JSON.stringify(this.user));
    await this.store.flush();
  }
}
