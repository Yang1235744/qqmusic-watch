import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../AppState';
import { QQLoginManager, QQLoginUser } from '../utils/QQLoginManager';
import { LocalCacheManager } from '../utils/LocalCacheManager';
import { FavoritesManager } from '../utils/FavoritesManager';

/**
 * 用户设置页 — 登录 / 离线缓存管理 / 云端同步开关
 *
 * 功能：
 *   - QQ 登录（二维码扫码、账号密码、OAuth 三种方式占位）
 *   - 离线缓存查看与清理
 *   - 云端收藏同步开关（需先登录）
 */
@Entry
@Component
struct UserSettingsPage {
  @State appState: AppState = new AppState();
  @State loginLoading: boolean = false;
  @State cacheSizeMB: number = 0;
  @State syncEnabled: boolean = false;
  private loginMgr: QQLoginManager = QQLoginManager.getInstance();
  private cacheMgr: LocalCacheManager = LocalCacheManager.getInstance();
  private favMgr: FavoritesManager = FavoritesManager.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.appState.refreshFromStorage();
    await this.loginMgr.init();
    await this.favMgr.init();
    this.syncEnabled = this.appState.syncToCloudEnabled;
    this.cacheSizeMB = Math.round(this.cacheMgr.getTotalCacheSize() / (1024 * 1024));
  }

  // ── 登录相关 ────────────────────────────────────────────────────

  /**
   * 尝试使用 QR Code 扫码登录（框架桩，待接入真实 SDK）
   */
  async handleQRLogin(): Promise<void> {
    if (this.loginLoading) return;
    this.loginLoading = true;
    try {
      await this.loginMgr.loginWithQRCode();
      await this.appState.refreshFromStorage();
      promptAction.showToast({ message: '登录成功！' });
    } catch (e) {
      const msg = (e as Error).message;
      if (msg.includes('尚未接入') || msg.includes('需要接入')) {
        // 展示登录 UI 引导用户手动操作
        this.showLoginGuide();
      } else {
        promptAction.showToast({ message: '登录失败：' + msg });
      }
    } finally {
      this.loginLoading = false;
    }
  }

  /**
   * 弹出 QQ 登录引导弹窗（提示用户在手机上操作）
   * TODO: 替换为实际的 WebView OAuth 页面或 harmony-qq-sdk 调用
   */
  showLoginGuide(): void {
    promptAction.showDialog({
      title: 'QQ 登录',
      message: '请在手机QQ中打开以下链接完成授权：\n\n'
        + 'https://graph.qq.com/oauth2.0/authorize\n'
        + '?client_id=101958944\n'
        + '&redirect_uri=https://y.qq.com/portal/wx_redirect.html\n'
        + '&response_type=code&scope=get_user_info\n\n'
        + '授权后在本页点击「确认已授权」继续。',
      buttons: [
        { text: '取消', color: '#999999' },
        {
          text: '确认已授权',
          color: '#FF31C27C',
          onClick: async () => {
            // TODO: 实际实现中这里通过回调 URL 提取 code
            // 当前仅做占位，提示开发者补充 SDK 接入代码
            promptAction.showToast({ message: '请在此处接入QQ开放平台SDK获取授权码', duration: 3000 });
          }
        }
      ]
    });
  }

  /**
   * 账号密码登录（占位）
   */
  async handlePasswordLogin(qqNumber: string, _password: string): Promise<void> {
    if (this.loginLoading) return;
    if (!qqNumber.trim()) {
      promptAction.showToast({ message: '请输入QQ号' });
      return;
    }
    this.loginLoading = true;
    try {
      await this.loginMgr.loginWithPassword(qqNumber, _password);
      await this.appState.refreshFromStorage();
      promptAction.showToast({ message: '登录成功！' });
    } catch (e) {
      promptAction.showToast({ message: '登录失败：' + (e as Error).message });
    } finally {
      this.loginLoading = false;
    }
  }

  /** 退出登录 */
  async handleLogout(): Promise<void> {
    try {
      await this.loginMgr.logout();
      this.appState.isLoggedIn = false;
      this.appState.currentUser = null;
      promptAction.showToast({ message: '已退出登录' });
    } catch (e) {
      promptAction.showToast({ message: '退出失败：' + (e as Error).message });
    }
  }

  // ── 缓存相关 ────────────────────────────────────────────────────

  /** 刷新缓存大小显示 */
  async refreshCacheInfo(): Promise<void> {
    this.cacheSizeMB = Math.round(this.cacheMgr.getTotalCacheSize() / (1024 * 1024));
  }

  /** 清除全部缓存 */
  async clearCache(): Promise<void> {
    try {
      await this.cacheMgr.clearAll();
      this.cacheSizeMB = 0;
      promptAction.showToast({ message: '缓存已清除' });
    } catch (e) {
      promptAction.showToast({ message: '清除失败：' + (e as Error).message });
    }
  }

  // ── 云端同步开关 ────────────────────────────────────────────────

  onSyncToggle(enabled: boolean): void {
    this.syncEnabled = enabled;
    this.appState.syncToCloudEnabled = enabled;
    if (enabled && !this.appState.isLoggedIn) {
      promptAction.showToast({ message: '请先登录QQ后再开启云端同步' });
      this.syncEnabled = false;
      this.appState.syncToCloudEnabled = false;
      return;
    }
    promptAction.showToast({
      message: enabled ? '云端同步已开启（登录后自动生效）' : '云端同步已关闭'
    });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 顶部导航栏
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
            .onClick(() => router.back())
          Text('设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })

        // ── QQ 登录区 ────────────────────────────────────────────
        Column({ space: 12 }) {
          Text('QQ 登录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Start)

          if (this.appState.isLoggedIn && this.appState.currentUser) {
            // 已登录状态卡片
            Row() {
              if (this.appState.currentUser.avatarUrl) {
                Image(this.appState.currentUser.avatarUrl)
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .objectFit(ImageFit.Cover)
              } else {
                Circle()
                  .width(44)
                  .height(44)
                  .fill('#FF31C27C')
                  .overflow(Overflow.Clip)
                Text(this.appState.currentUser.nickName.charAt(0).toUpperCase())
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              Column() {
                Text(this.appState.currentUser.nickName)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                Text(`QQ: ${this.appState.currentUser.qqNumber}`)
                  .fontSize(12)
                  .fontColor('#B0B0B0')
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .margin({ left: 12 })
              .alignItems(HorizontalAlign.Start)

              Text('退出')
                .fontSize(13)
                .fontColor('#FF6B6B')
                .onClick(() => this.handleLogout())
            }
            .width('100%')
            .height(68)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#1A1A1A')
            .borderRadius(12)
          } else {
            // 未登录：展示登录按钮组
            Column({ space: 10 }) {
              // 方式一：二维码扫码
              Button('📱 扫码登录（推荐）')
                .width('100%')
                .height(48)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor('#FF31C27C')
                .borderRadius(12)
                .onClick(() => this.handleQRLogin())

              // 方式二：账号密码（占位）
              Button('🔑 QQ 号密码登录')
                .width('100%')
                .height(48)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor('#2A2A2A')
                .borderRadius(12)
                .onClick(async () => {
                  // 简单输入框登录（占位演示）
                  promptAction.showDialog({
                    title: 'QQ 登录',
                    message: '请在手机QQ中扫描下方二维码或通过OAuth网页完成授权。\n\n'
                      + '【开发者说明】\n'
                      + '将 https://open.qq.com 注册的应用 AppID 填入 QQLoginManager.ets\n'
                      + '中的 QQ_CLIENT_ID 常量即可启用真实登录流程。',
                    buttons: [{ text: '知道了', color: '#FF31C27C' }]
                  });
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor('#1A1A1A')
            .borderRadius(12)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#111111')
        .borderRadius(16)

        // ── 离线缓存区 ────────────────────────────────────────────
        Column({ space: 10 }) {
          Row() {
            Text('离线缓存')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            Text(`${this.cacheSizeMB} MB`)
              .fontSize(13)
              .fontColor('#B0B0B0')
          }
          .width('100%')

          // 缓存占用可视化条
          Progress({ value: Math.min(this.cacheSizeMB / 500 * 100, 100), type: ProgressBarType.Line })
            .width('100%')
            .height(4)
            .color('#FF31C27C')
            .backgroundColor('#333333')
            .borderRadius(2)

          Row() {
            Button('刷新')
              .height(36)
              .fontSize(13)
              .fontColor('#FF31C27C')
              .backgroundColor('transparent')
              .border({ width: 1, color: '#FF31C27C' })
              .borderRadius(18)
              .onClick(() => this.refreshCacheInfo())
            Blank()
            Button('清除全部缓存')
              .height(36)
              .fontSize(13)
              .fontColor('#FF6B6B')
              .backgroundColor('transparent')
              .border({ width: 1, color: '#FF6B6B' })
              .borderRadius(18)
              .onClick(() => this.clearCache())
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1A1A1A')
        .borderRadius(16)

        // ── 云端同步区 ────────────────────────────────────────────
        Column({ space: 10 }) {
          Row() {
            Text('云端收藏同步')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            Toggle({ isOn: this.syncEnabled })
              .mode(ToggleMode.CHECKBOX)
              .onChange((on: boolean) => this.onSyncToggle(on))
          }
          .width('100%')

          Text(this.syncEnabled
            ? (this.appState.isLoggedIn
              ? '✅ 已开启 — 收藏将自动同步至你的QQ账号'
              : '⚠️ 请先登录后开启此功能')
            : '关闭 — 收藏仅保存在本机')
            .fontSize(12)
            .fontColor('#888888')
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1A1A1A')
        .borderRadius(16)

        // ── 关于 ────────────────────────────────────────────────────
        Column({ space: 8 }) {
          Text('关于')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Start)
          Text('QQ音乐 · 华为 Watch Fit 3 穿戴版')
            .fontSize(13)
            .fontColor('#888888')
          Text('版本 1.0.0  |  仅供学习研究使用')
            .fontSize(12)
            .fontColor('#555555')
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#111111')
        .borderRadius(16)
        .margin({ bottom: 32 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
