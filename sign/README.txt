# 签名文件目录

将以下签名文件放入此目录：

- `qqmusic_watch.p12` - 密钥库文件（包含私钥）
- `qqmusic_watch.cer` - 数字证书（从华为开发者平台获取）
- `qqmusic_watch.p7b` - Profile 配置文件（从华为开发者平台获取）

## 获取签名文件步骤：

1. 访问华为开发者联盟：https://developer.huawei.com/
2. 注册/登录开发者账号
3. 进入「用户与访问」->「证书管理」
4. 生成 CSR 并申请发布证书（.cer）
5. 下载证书并生成 .p12 密钥库
6. 进入「产品管理」创建应用，获取 Profile（.p7b）
7. 将三个文件放入此目录，并修改 build-profile.json5 中的密码配置

详细说明见项目根目录的《打包签名与上架指南.md》。
