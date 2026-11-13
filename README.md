# QQ音乐手表版（华为 Watch Fit 3）

HarmonyOS 穿戴应用，为华为 Watch Fit 3 提供 QQ 音乐在线搜索与播放功能。  
仅供学习研究使用，非官方产品，版权归腾讯所有。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-4.0%2B-orange)](https://developer.huawei.com/consumer/cn/deveco-studio/)
[![ArkTS](https://img.shields.io/badge/language-ArkTS-green.svg)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-overview-V5)

---

## 功能

- ✅ QQ 音乐在线搜索（歌曲名 / 歌手 / 专辑）
- ✅ 在线播放（m4a 格式，依托 QQ 公开 Web API）
- ✅ 播放控制：播放/暂停、进度拖动、停止
- ✅ 专辑封面显示
- ✅ 适配 1.82 英寸矩形 AMOLED 屏幕
- ✅ 深色主题（AMOLED 省电）

## 已知限制

- ❌ 不支持 QQ 账号登录
- ❌ 不支持个人歌单 / 收藏同步
- ❌ 不支持歌词显示
- ❌ 部分付费/VIP 歌曲无法播放
- ❌ 无后台保活（需配合长时任务框架）

---

## 快速开始

### 环境要求

- DevEco Studio 5.x+（含 HarmonyOS SDK 4.0.0(10) 或以上）
- JDK 17+
- 华为 Watch Fit 3（或模拟器）

### 构建步骤

```bash
# 1. 用 DevEco Studio 打开本项目根目录
# 2. 等待项目同步完成（自动下载 ohpm 依赖）
# 3. Build -> Build Hap(s) -> Build Hap(s)
```

或使用命令行：

```powershell
.\hvigorw.bat assembleHap --mode module -p product=default --no-daemon
```

HAP 输出路径：`entry/build/default/outputs/default/entry-default-unsigned.hap`

### 签名说明

> ⚠️ **签名文件（`.p12` / `.cer` / `.p7b`）未随本项目发布**，开发者需自行在华为开发者联盟申请。  
> 详细步骤见 [打包签名与上架指南.md](./打包签名与上架指南.md)。

---

## 项目结构

```
qqmusic-watch/
├── AppScope/                   # 全局配置（包名、版本）
│   └── app.json5
├── entry/                      # 主模块
│   ├── src/main/ets/
│   │   ├── entryability/       # 入口 Ability
│   │   ├── pages/              # UI 页面
│   │   │   ├── Index.ets       # 首页（热门推荐）
│   │   │   ├── Search.ets      # 搜索页
│   │   │   └── Player.ets      # 播放器页
│   │   ├── model/              # 数据模型
│   │   └── utils/              # 工具类
│   │       ├── QQMusicApi.ets  # QQ音乐 Web API 封装
│   │       └── AudioPlayer.ets # AVPlayer 音频播放
│   └── src/main/module.json5   # 模块配置（权限、设备类型）
├── sign/                       # 签名文件目录（请自行填入）
├── build.ps1                   # Windows 一键构建脚本
└── 打包签名与上架指南.md        # 完整构建 & 上架腕连社区教程
```

---

## API 说明

本项目调用 QQ 音乐网页端公开接口：

| 接口 | 用途 |
|------|------|
| `c.y.qq.com/soso/fcgi-bin/client_search_cp` | 歌曲搜索 |
| `c.y.qq.com/base/fcgi-bin/fcg_music_express_mobile3.fcg` | 获取播放地址（vkey） |

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
