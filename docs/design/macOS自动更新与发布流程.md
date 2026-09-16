# macOS 自动更新与发布流程

## 1. 目标与边界

Egangnal 使用 Sparkle 2 为非 Mac App Store 版本提供应用内更新。

更新流程为：

1. 应用读取 `appcast.xml`。
2. Sparkle 比较当前 `CFBundleVersion` 与远端版本。
3. 用户确认后下载完整的新版应用压缩包。
4. Sparkle 验证 EdDSA 更新签名，并检查应用包的代码签名结构。
5. 退出旧版本，替换 `Egangnal.app`，再启动新版本。

Sparkle 不提供文件托管服务。`appcast.xml`、更新包和更新说明必须放在开发者选择的 HTTPS 静态托管服务中。

## 2. 当前项目配置

- Sparkle Swift Package：`2.9.6`
- Bundle ID：`com.ly.Egangnal`
- Sparkle 密钥账户：`com.ly.Egangnal`
- Sparkle 公钥：已写入主 target 的 `SUPublicEDKey`
- Sparkle 私钥：只保存在当前 Mac 的登录钥匙串，不进入仓库
- 更新入口：设置页面的“应用更新”区域
- 自动后台检查：首版关闭，仅由用户手动点击“检查更新”
- App Sandbox：已允许客户端 HTTPS 网络访问，并声明 Sparkle 安装器/状态连接服务所需的 Mach lookup 权限
- Sparkle 沙盒安装器启动服务：`SUEnableInstallerLauncherService = true`
- Release 更新源：`https://leebh6045-lang.github.io/Egangnal/updates/appcast.xml`
- Release：已开启 Hardened Runtime，当前个人发布使用 ad-hoc 签名
- Release 权限文件：`EgangnalRelease.entitlements`，仅个人 ad-hoc 方案开启 Library Validation 例外，使无 Team ID 的主应用可以加载 Sparkle 框架

Debug 的 `EGANGNAL_UPDATE_FEED_URL` 保持为空，避免开发和单元测试访问正式更新源；Release 已配置固定的 GitHub Pages 地址，不需要修改业务代码。

## 3. 首次发布前的一次性准备

### 3.1 选择托管位置

当前使用公开 GitHub 仓库 `leebh6045-lang/Egangnal`：GitHub Release 存放完整应用 ZIP，GitHub Pages 的 `updates` 目录存放 `appcast.xml`。应用匿名读取公开文件，不在应用内保存 GitHub Token。

固定地址为：

```text
https://leebh6045-lang.github.io/Egangnal/updates/appcast.xml
https://github.com/leebh6045-lang/Egangnal/releases/download/v1.0.1/Egangnal-1.0.1.zip
```

不要使用需要登录、Cookie 或临时签名参数的下载地址。Sparkle 必须能够直接访问这些文件。

### 3.2 填写更新源

在 Xcode 中选择：

```text
Egangnal project → Egangnal target → Build Settings
```

搜索并填写：

```text
EGANGNAL_UPDATE_FEED_URL
```

只在 **Release** 配置中填写正式 HTTPS `appcast.xml` 地址；Debug 保持空值，避免开发和单元测试误访问正式更新源。正式发布前应在 Release 构建产物中确认：

```bash
plutil -p Egangnal.app/Contents/Info.plist | grep -E 'SUFeedURL|SUPublicEDKey'
```

首个正式版本发布后，旧版本已经把这个 Feed URL 写入应用包，因此该地址应长期稳定；更换托管服务时应保留原地址或设置 HTTPS 重定向。

### 3.3 备份 Sparkle 私钥

私钥丢失后，已发布的旧版本将无法验证由新密钥签名的更新。首次正式发布前必须备份：

```bash
generate_keys --account com.ly.Egangnal -x "$HOME/Documents/Egangnal-Sparkle-private-key"
```

导出的文件等同于密码，只应保存在密码管理器或离线加密存储中。示例路径位于项目目录之外；不要把它放入项目目录、Git、网盘公开目录或应用包。

恢复到另一台开发 Mac：

```bash
generate_keys --account com.ly.Egangnal -f "$HOME/Documents/Egangnal-Sparkle-private-key"
```

## 4. 当前个人签名策略

当前不加入 Apple Developer Program，因此采用两层校验：

1. Release 应用使用本机 ad-hoc 签名，保证应用、Sparkle 框架和辅助服务具有完整代码签名结构。
2. 更新 ZIP 使用 Sparkle EdDSA 私钥签名，已安装版本通过内置公钥验证更新来源和内容完整性。

ad-hoc 签名不能替代 Developer ID 和 Apple 公证。首次从 GitHub 下载后，macOS 仍可能提示无法验证开发者，需要本人右键打开，或在“系统设置 → 隐私与安全性”中允许。未来若对外分发，再切换到 `Developer ID Application + Apple notarization`，无需更换 Sparkle 更新协议。

Hardened Runtime 默认要求主应用与动态框架拥有相同 Team ID，但 ad-hoc 签名没有 Team ID。Release 因此通过 `com.apple.security.cs.disable-library-validation` 允许加载随应用一起分发的 Sparkle 框架。该权限不替代 Sparkle EdDSA 更新签名；每个更新 ZIP 仍必须使用私钥签名。未来切换到 Developer ID 后，应删除这项例外并恢复完整的 Library Validation。

Sparkle 私钥是当前更新链的唯一稳定信任根。发布前使用 `generate_keys --account com.ly.Egangnal -p` 检查输出必须与 `Info.plist` 中的 `SUPublicEDKey` 完全一致。

## 5. 每次发布新版本

首次引导版为 `1.0.0 / Build 1`，必须手动安装一次。下面以首个可被检测到的更新 `1.0.1 / Build 2` 为例。

### 5.1 更新版本号

在主 target 的 General 页面设置：

```text
Version = 1.0.1
Build = 2
```

规则：

- `Version` 是用户看到的语义版本号。
- `Build` 即 `CFBundleVersion`，每次发布必须严格递增。
- 不要重复使用已经发布过的 Build。

### 5.2 验证代码

```bash
xcodebuild \
  -project Egangnal.xcodeproj \
  -scheme Egangnal \
  -destination 'platform=macOS' \
  test
```

### 5.3 构建并进行 ad-hoc 签名

使用独立构建目录生成 Release 应用，并明确指定本地 ad-hoc 签名身份 `-`：

```bash
xcodebuild \
  -project Egangnal.xcodeproj \
  -scheme Egangnal \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/EgangnalReleaseDerivedData \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM= \
  build
```

完成后检查代码签名和关键配置：

```bash
codesign --verify --deep --strict --verbose=2 \
  /tmp/EgangnalReleaseDerivedData/Build/Products/Release/Egangnal.app

codesign -d --entitlements :- \
  /tmp/EgangnalReleaseDerivedData/Build/Products/Release/Egangnal.app

plutil -p \
  /tmp/EgangnalReleaseDerivedData/Build/Products/Release/Egangnal.app/Contents/Info.plist \
  | grep -E 'CFBundleShortVersionString|CFBundleVersion|SUFeedURL|SUPublicEDKey'
```

`spctl` 不会把 ad-hoc 应用判断为已公证软件，这是当前个人方案的已知限制，不属于构建失败。

当前 ad-hoc Release 的权限检查结果必须包含 `com.apple.security.cs.disable-library-validation = true`，并且不能包含调试权限 `com.apple.security.get-task-allow`。如果缺少前者，应用会在启动阶段因 Sparkle 框架与主应用没有 Team ID 而被 Hardened Runtime 拒绝加载。

### 5.4 准备更新目录

```text
SparkleReleases/
├── Egangnal-1.0.1.zip      ← 本地暂存，不入库（.gitignore）
├── Egangnal-1.0.1.md       ← 入库，作为该版本的发布记录
└── Egangnal-1.0.1.zip.sha256  ← 入库
```

这个目录是**本地暂存区**：ZIP 放在这里是为了下一步生成 appcast 与上传 Release，
提交时只带 `.md` 与 `.sha256`。ZIP 体积在 4–6 MB，且更新链只从 GitHub Release 取它。

使用 `ditto` 压缩已签名应用，避免破坏 macOS 扩展属性：

```bash
ditto -c -k --sequesterRsrc --keepParent \
  /tmp/EgangnalReleaseDerivedData/Build/Products/Release/Egangnal.app \
  SparkleReleases/Egangnal-1.0.1.zip
```

同名 Markdown 文件是该版本的更新说明，例如：

```markdown
# Egangnal 1.0.1

- 优化单词刷导航体验。
- 修复已知问题。
```

### 5.5 生成并签名 Appcast

Sparkle 的工具位于 Xcode 的 Swift Package artifact 目录。可先查找：

```bash
find ~/Library/Developer/Xcode/DerivedData \
  -path '*Sparkle/bin/generate_appcast' \
  -type f \
  -print -quit
```

**⚠️ 这一次发布只放"本次这一个 ZIP"进暂存目录**（2026-09-16 补记）。

`--download-url-prefix` 会把目录里**所有** ZIP 的下载地址都改写成同一个前缀。
若把历史版本的 ZIP 一并放进去，旧版本条目就会指向新 tag 下并不存在的资产——
2026-09-13 发布 1.0.4 时真实发生过：1.0.1 与 1.0.2 的地址被改写成
`.../download/v1.0.4/Egangnal-1.0.1.zip`，装了旧版本的用户点更新会下载失败。

因此推荐的做法是**用一个干净的临时目录**生成，再把结果拷回来：

```bash
rm -rf /tmp/eg-feed && mkdir -p /tmp/eg-feed
cp SparkleReleases/Egangnal-1.0.6.zip SparkleReleases/Egangnal-1.0.6.md /tmp/eg-feed/

/找到的路径/generate_appcast \
  --account com.ly.Egangnal \
  --download-url-prefix 'https://github.com/leebh6045-lang/Egangnal/releases/download/v1.0.6/' \
  --embed-release-notes \
  /tmp/eg-feed

cp /tmp/eg-feed/appcast.xml updates/appcast.xml
```

代价是不会有增量更新（`.delta`）——增量只在目录里同时存在"上一个版本"时才会生成。
按需权衡：想要增量就把**确实存在对应 Release 资产**的上一版 ZIP 也放进去，
并逐个核对生成结果里的每一个 `enclosure url`。

工具会：

- 从 ZIP 内读取版本号和最低系统版本。
- 使用钥匙串中的私钥签名更新包。
- 生成或更新暂存目录里的 `appcast.xml`（正式那份要拷到 `updates/appcast.xml`）。
- 为适合的历史版本生成增量更新；只有完整 ZIP 也可以正常更新。

生成签名后不要手动修改 ZIP。修改 ZIP 后必须重新运行 `generate_appcast`。

**生成后必须核对**：`grep -oE 'url="[^"]+"' appcast.xml`，逐个确认地址里的 tag 与文件名都对得上。

### 5.6 上传文件

上传 `appcast.xml` 中引用的全部文件，至少包括：

```text
Egangnal-1.0.1.zip
appcast.xml
```

如果工具生成了 `.delta` 或其他辅助文件，也必须一并上传；不能只上传 XML。

如果更新说明没有嵌入 Appcast，还需要上传对应的 HTML、Markdown 或文本说明文件。

**这些产物都不进入仓库**（2026-09-16 起）：ZIP 作为 GitHub Release 资产上传即可，
仓库里留一份副本对更新链没有任何作用，只会让仓库每次发布涨 4–6 MB。
`SparkleReleases/*.zip` 已在 `.gitignore` 中；`.md`（更新说明）与 `.sha256`（校验值）仍然入库，
作为每个版本的轻量发布记录。仓库里已入库的 1.0.1 / 1.0.2 / 1.0.4 / 1.0.5 四个 ZIP
已于 2026-09-16 取消跟踪（历史提交里仍存在，未重写历史）。

上传位置和顺序：

1. 先把 ZIP 作为 `v1.0.1` GitHub Release 的资产上传。
2. 验证 ZIP 的公开 HTTPS 地址可直接下载。
3. 最后把 `appcast.xml` 提交到仓库的 `updates/appcast.xml`，由 GitHub Pages 发布。

最后上传 Appcast 可以避免用户先看到新版本，但更新包还没有传完。

## 6. 发布后验证

1. 保留一份旧版本 Egangnal。
2. 打开旧版本设置页。
3. 点击“检查更新”。
4. 核对版本号、说明和下载大小。
5. 完成安装并重启。
6. 检查单词本、学习时长和设置数据仍然存在。
7. 检查新版本的设置页再次检查时显示已是最新版。

还应测试：无网络、下载中断、错误签名、用户取消以及只读安装目录等场景。

## 7. 安全原则

- Sparkle 私钥永远不能写入仓库或应用包。
- 更新源和下载地址必须使用 HTTPS。
- 个人发布至少保持有效的 ad-hoc 代码签名；未来对外分发时升级为 Developer ID 签名与 Apple 公证。
- 每次发布都递增 Build。
- 发布前备份本地数据并验证数据模型迁移。
- 不要覆盖用户的 SwiftData 数据目录；更新只替换 `Egangnal.app`。
