# 智学伴 iOS App

原生壳 + WKWebView 加载线上站点（`https://xue.zhijiyy.com/`），与 Android 壳同架构。
支持 iPhone / iPad，iOS 13+，横竖屏。前端已加 `.zxb-ios` 适配（iPad 宽屏强制手机布局）。

## 工作原理

- 原生层：Swift + WKWebView，只做加载、UA 标识、外链拦截、进度条
- 前端：UA 含 `ZhiXueBanApp/7` 时加 `.zxb-app` + `.zxb-ios` class
  - `.zxb-app` → 压 PC 壳（已有）
  - `.zxb-ios` → 抵消 iPad 宽屏的 PC 三栏断点，强制 480px 手机壳居中（B197，已上线）
- 所有业务功能都在 Web 端，改前端无需重新发版

## 工程结构

```
ZhiXueBan-iOS/
├── ZhiXueBan/
│   ├── project.yml                 # XcodeGen 配置（CI 用它生成 xcodeproj）
│   └── ZhiXueBan/
│       ├── AppDelegate.swift
│       ├── MainViewController.swift  # 核心：WKWebView 壳
│       ├── Info.plist
│       ├── LaunchScreen.storyboard
│       └── Assets.xcassets/AppIcon.appiconset/  # 1024 图标
├── .github/workflows/build-ios.yml  # 云端 Mac 编译+签名+上架
└── ExportOptions.plist.template     # 导出配置模板
```

## 你需要准备的材料（关键，缺一不可）

### 1. 苹果开发者后台（developer.apple.com，用你给的账号登录）

1. **确认已付费加入 Apple Developer Program**（你说已付费）
2. 记下 **Team ID**：后台右上角 `Membership` → Team ID（类似 `A1B2C3D4E5`）
3. **创建 App ID（Identifiers）**：
   - Identifiers → + → App IDs
   - Bundle ID 填 `com.zhixueban.app`（与工程一致）
   - 勾能力：无特殊要求（网络/音频默认可用）
4. **创建 App Store 描述文件（Profiles）**：
   - Profiles → + → App Store → 选刚建的 App ID → 选发布证书 → 命名（如 `ZhiXueBan AppStore`）
   - 下载 `.mobileprovision` 文件
5. **创建发布证书 + p12**：
   - Certificates → + → Apple Distribution → 需要一台 Mac 用 Keychain 生成 CSR（见下）或让 CI 生成
   - 导出 `.p12` 时设一个密码
6. **App Store Connect 创建 App**：
   - appstoreconnect.apple.com → 我的 App → + → 新 App
   - 名称「智学伴」、Bundle ID `com.zhixueban.app`、SKU 自填

### 2. App Store Connect API 密钥（CI 上传用）

- App Store Connect → 用户和访问 → API 密钥 → + → 名称随意、权限选 **App Manager**
- 下载 `.p8` 文件，记下 **Key ID** 和 **Issuer ID**

### 3. 关于 CSR / p12（需要一次 Mac）

不需要 Mac！我提供了 `make_csr.sh`，Windows（Git Bash）直接跑：

```bash
bash make_csr.sh        # 生成 ios_dist.key（私钥）+ ios_dist.csr
```

然后：
1. 把 `ios_dist.csr` 传到苹果后台 Certificates → + → Apple Distribution
2. 下载签发的 `.cer`，按脚本末尾提示用 openssl 导出 `cert.p12`（设个密码）
3. 把 p12 私钥和证书 base64 后填入 GitHub Secrets

私钥 `ios_dist.key` 和 p12 请妥善保管、别外传。

## GitHub Secrets 准备

在 GitHub 仓库 `Settings → Secrets and variables → Actions` 添加：

| Secret | 值 |
|---|---|
| `APPLE_TEAM_ID` | 上面的 Team ID |
| `IOS_CERT_P12_BASE64` | p12 文件 base64（`base64 -i cert.p12`） |
| `IOS_CERT_PASSWORD` | p12 导出密码 |
| `KEYCHAIN_PASSWORD` | 自定义一个密码，CI 临时钥匙串用 |
| `IOS_PROVISIONING_PROFILE_BASE64` | mobileprovision 文件 base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | 描述文件名字（如 `ZhiXueBan AppStore`） |
| `APPSTORE_API_KEY_BASE64` | .p8 文件 base64 |
| `APPSTORE_API_KEY_ID` | Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `IOS_EXPORT_PLIST_BASE64` | ExportOptions.plist（按模板替换后）base64 |

## 编译发布

1. 把整个 `ZhiXueBan-iOS` 目录推到 GitHub 仓库
2. Actions → `Build & Distribute iOS` → Run workflow
   （或打 tag `ios-1.0.0` 自动触发）
3. CI 在 macOS runner 上：生成工程 → 导入证书 → 编译 → 导出 IPA → 上传 App Store Connect
4. 到 App Store Connect 处理构建版本（填隐私清单、截图、描述）→ 提交审核

## 已知限制

- 首次提交 App Store 需要苹果审核（1-3 天）
- 隐私清单（Privacy Manifest）：iOS 17+ 上架可能需要，WKWebView 一般无需额外声明，若被拒再补
- ATS：Info.plist 已允许 WebView 内容加载 http 资源，生产建议全站 HTTPS 后收紧
- 版本号在 `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 改

## 本地验证状态

已用 Playwright 模拟 iPhone(390×844)、iPad Pro(1366×1024)、iPad Air、iPad Mini：
- `.zxb-ios` class 生效、ios_app.css 加载 ✅
- iPad 三栏断点被抵消、手机壳 480px 居中、body 无 PC 留白 ✅
- 登录页完整、零 JS 错误 ✅
