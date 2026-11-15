# QQ音乐手表版（华为 Watch Fit 3）

HarmonyOS 穿戴应用，为华为 Watch Fit 3 提供 QQ 音乐的**搜索、播放、离线缓存、登录收藏**功能。  
仅供学习研究使用，非官方产品，版权归腾讯所有。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0%2B-orange)](https://developer.huawei.com/consumer/cn/deveco-studio/)
[![ArkTS](https://img.shields.io/badge/language-ArkTS-green.svg)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-overview-V5)

---

## 功能清单

### 已实现 ✅

- **在线搜索** — 按歌名 / 歌手 / 专辑调用 QQ 公开 API
- **在线播放** — m4a 流媒体，AVPlayer 硬件解码
- **播放队列** — 搜索结果整组入队，播完自动切下一首；上一曲 / 下一曲按钮
- **歌词显示** — 播放器页右上角"歌词"按钮展开滚动面板，高亮当前行
- **离线缓存** — 点击下载按钮将歌曲存至设备本地 `CachedData/`，无网络时优先播本地版
- **QQ 登录框架** — OAuth 2.0 完整桩代码（扫码 / 密码 / Code 回调），token 持久化存储
- **云端收藏开关** — 登录后开启「云端同步」后收藏数据自动上传（需接入云接口）
- **后台持续播放** — 声明 `backgroundModes: audioPlayback` + MEDIA_CONSOLE 权限，App 切后台继续播
- **深色 AMOLED 主题** — 纯黑背景 + 粉色点缀，适配 1.82″ OLED 屏幕省电
- **VIP 歌曲标识** — 带 VIP 标签的列表项，点击友好提示，不支持下载

### 待后续开发者完成 🔲

| 功能 | 状态文件 | TODO 说明 |
|------|----------|-----------|
| QQ 真实登录 | `QQLoginManager.ets` | 填入 AppID → 替换占位 API 为 harmony-qq-sdk 或 WebView |
| 云端收藏同步 | `FavoritesManager.ets` | 接入 QQ 开放平台云收藏接口 |
| 系统媒体通知 | `MediaNotification.ets` | 调用 `media.getNotificationManager()` 推送真实通知 |
| 断点续传下载 | `LocalCacheManager.ets` | 接入 `DownloadService` 系统级下载服务 |
| 稳定后台保活 | `EntryAbility.ets` | HarmonyOS 4.1+ 申请 `AUTO_BACKGROUND_RUNNING` 权限 |

---

## 快速开始

### 环境要求

- DevEco Studio 5.x+（含 HarmonyOS SDK 4.0.0(10) 或以上）
- JDK 17+
- 华为 Watch Fit 3（或模拟器）

### 构建步骤

```powershell
# 命令行一键构建
.\hvigorw.bat assembleHap --mode module -p product=default --no-daemon
```

或在 DevEco Studio：**Build → Build Hap(s) → Build Hap(s)**

HAP 输出路径：`entry/build/default/outputs/default/entry-default-unsigned.hap`

### 签名说明

> ⚠️ **签名文件（`.p12` / `.cer` / `.p7b`）未随本项目发布**，开发者需自行在华为开发者联盟申请。  
> 详细步骤见 [打包签名与上架指南.md](./打包签名与上架指南.md)。

---

## 项目结构

```
qqmusic-watch/
├── AppScope/app.json5                   # 包名：com.qqmusic.watch.fit3
├── index.html                           # GitHub Pages 官网落地页
├── entry/src/main/ets/
│   ├── AppState.ets                     # 全局状态（登录态/当前歌曲/播放状态）
│   ├── entryability/EntryAbility.ets    # 应用入口（音频会话 + 服务初始化）
│   ├── pages/
│   │   ├── Index.ets                    # 首页（热门 / 离线 / 收藏 三 Tab）
│   │   ├── Search.ets                   # 搜索页（含收藏/下载操作按钮）
│   │   ├── Player.ets                   # 播放器（歌词 / 离线下载 / 控制）
│   │   └── UserSettingsPage.ets         # 设置页（登录 / 缓存管理 / 云端同步）
│   ├── utils/
│   │   ├── QQMusicApi.ets               # 搜索 & 播放地址 API
│   │   ├── AudioPlayer.ets              # AVPlayer 封装（含播放队列）
│   │   ├── LocalCacheManager.ets        # 离线缓存读写
│   │   ├── QQLoginManager.ets           # QQ OAuth 登录框架
│   │   ├── MediaNotification.ets        # 后台媒体通知
│   │   └── FavoritesManager.ets         # 本地收藏持久化
│   └── model/Song.ets                   # 歌曲数据模型
├── sign/                                # 签名文件目录（请自行填入 .p12/.cer/.p7b）
├── build.ps1                            # Windows 一键构建脚本
└── README.md
```

---

## 接入 QQ 登录（给开发者的指引）

`QQLoginManager.ets` 中已预留完整的 OAuth 2.0 流程，只需做三步即可跑通：

```typescript
// 1. 在 QQLoginManager.ets 顶部填入你的 AppID
const QQ_CLIENT_ID = 'YOUR_APP_ID';           // https://open.qq.com 注册获取
const QQ_REDIRECT_URI = 'https://your-domain.com/callback';

// 2. 启动时由 Ability 调用 init() 恢复上次登录态
await QQLoginManager.getInstance().init();

// 3. 实现 loginWithQRCode() / loginWithCode(code) 中的真实 API 调用
//    参考文档：https://wiki.connect.qq.com/%e5%bc%80%e5%8f%91%e6%94%bb%e7%95%a5_pc%e7%ab%af%e6%8e%88%e6%9d%83%e7%8a%b6%e6%80%81
```

---

## API 说明

本项目调用 QQ 音乐网页端公开接口：

| 接口 | 用途 |
|------|------|
| `c.y.qq.com/soso/fcgi-bin/client_search_cp` | 歌曲搜索 |
| `c.y.qq.com/base/fcgi-bin/fcg_music_express_mobile3.fcg` | 获取播放地址（vkey） |
| `c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg` | 获取歌词文本 |

> 仅供学习与个人研究，请勿用于商业用途。

---

## 如何让别人也能做？

本仓库开放全部源码，任何人可在华为开发者联盟注册账号后：

1. 生成自己的 CSR（私钥密钥库）
2. 在 AGC 控制台申请调试/发布证书
3. 创建 HarmonyOS 应用并下载 Profile（`.p7b`）
4. 将三件套放入 `sign/` 目录，修改密码后构建

详见：[打包签名与上架指南.md](./打包签名与上架指南.md)

---

## 上架腕连社区

腕连社区（https://www.wristconnect.com）支持第三方手表应用分发：

1. 注册开发者账号
2. 上传已签名的 HAP + 图标 + 截图
3. 填写描述（注明「非官方」）
4. 选择适配机型：华为 Watch Fit 3
5. 提交审核（通常 1–3 个工作日）

---

## 许可

Apache-2.0。本项目仅用于学习 HarmonyOS ArkTS 开发，不拥有 QQ 音乐相关版权。
