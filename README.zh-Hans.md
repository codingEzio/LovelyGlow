<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

可选 Pixel 字体使用 DeparturePixelZh Compact 0.1.1，仓库不包含字体。打包前运行 `python3 script/get_compact_font.py` 下载并校验固定版本。声明与范围见[依赖说明](DEPENDENCIES.md)。 如需本地字体，构建时将 `LOVELYGLOW_PRIVATE_FONT` 设为字体文件路径。请将字体保存在仓库外或被忽略的 `Local/` 中；打包前会校验字体，可将 `LOVELYGLOW_PRIVATE_FONT_NOTICES` 设为对应声明目录；未提供时，软件包会标明没有提供声明。

macOS 原生菜单栏工具，为当前活动窗口绘制一圈边光。它不遮暗内容、不排列窗口，也不会接管其他 App 的窗口。

## 使用与行为

启用 Glow 后跟随前台 App 的当前窗口。小型无标题辅助窗口默认排除，可在 More 中明确开启。弹出自己的菜单、Cmd+Tab 或 Spotlight 时保持原窗口；全屏、Mission Control 和铺满工作区的窗口会隐藏边光。它始终不接收点击、不抢键盘焦点。

菜单栏弹出面板直接调整颜色、尺寸、运动、出现方式和字体。System 是默认字体，随附 Pixel Compact 可选并保存。Instant 和 Seamless 共用一个覆盖窗口；显示更新跟随当前屏幕节奏。核心测试不证明实际手势、屏幕流畅度或像素对齐。Stage Manager、自定义窗口形状与未来 macOS 的空间检测仍有限制。

## 源码构建

要求 Apple Silicon、macOS 27+，以及选中的兼容 Xcode／Swift 6.2+ SDK。没有下载的 Swift 包，也不依赖相邻仓库。先完成 Apple 官方的 Xcode 安装与许可确认。

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
python3 -m unittest discover -s script -p test_migrate_settings.py
```

`just` 只提供现有命令快捷方式；等效核心测试为 `swift test --jobs 2 --scratch-path Local/swift-test`。测试使用合成数据，不启动 App、不请求辅助功能权限、不安装或更改登录项。`SWIFT_JOBS` 默认 2；`SWIFT_SCRATCH_PATH` 默认 `Local/swift-test`。无效参数明确失败。

### 运行开发版

在仓库执行 `./script/dev.sh --run`，无需签名证书即可构建临时签名的 App 并在终端运行；按 Control-C 或使用 App 的退出命令停止。`./script/dev.sh --build` 只构建并输出路径；`just dev` 和 `just dev-build` 等效。每次构建会新建 `Local/lovelyglow-dev.*` 目录，并复用 `Local/swift-dev-build` SwiftPM 缓存。停止 App 后可手动删除不再需要的包目录；没有构建运行时可删除缓存以释放空间。失败的构建目录也会保留。

开发版使用独立身份 `com.github.codingEzio.LovelyGlow.Development` 和设置 `~/Library/Application Support/com.github.codingEzio.LovelyGlow.Development/config.toml`。设置在开发运行之间保留；仅在需要丢弃时手动删除该目录。使用权限控件主动请求辅助功能；启动时不会请求。如开启登录启动，删除 App 前先在开发版中关闭。清理后 macOS 可能保留权限记录。可选字体仅在下载或自行提供并校验后随包提供；没有字体时可使用系统字体。此流程不会安装或替换正式签名产品。

## 签名安装与权限

本机签名配置 `config/product.conf` 优先；没有时使用保留同一产品身份、无签名身份的 `config/product.public.conf`。此仓库不包含私人配置。编译成功不等于已有可运行的签名 App。

```sh
just stage
just install
```

这些命令需要你配置的本机证书和签名身份。Stage 构建独立候选，不停止日用 App；Install 核对签章要求，才替换并启动 `~/Applications/LovelyGlow.app`。不会改成临时签名或新 bundle ID 来绕过检查。打包使用原生 iconutil／sips、可选 rsvg-convert 与 Python 图标后备路径。

使用权限控件主动请求辅助功能权限；启动时不会请求。没有权限时，普通切换仍可使用窗口系统边界，但拖动跟随较弱。登录启动只由用户明确开启的 SMAppService 管理；没有 HTTP 服务、LaunchAgent 或 Process Compose。

## 数据与移转

0.7.9／33 起唯一活动设置为 `~/Library/Application Support/com.alex.LovelyGlow/config.toml`，不会把运行设置写回代码目录。安装器从旧签名 App 的元数据读取原路径，在停止旧进程后逐字节复制并读回。目标已有不同内容时中止，不覆盖任一文件；旧文件保留作恢复。新安装直接使用 Application Support。构建输出留在忽略的 Local／dist，不是用户设置目录。

## 许可与来源审阅

README 图标是 codingEzio 创作的独立文档 SVG，采用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。此授权不改变产品图标、字体或第三方权利。

自有软件采用 [MIT](LICENSE)。可选字体保留[完整 OFL 与组件声明](Resources/Licenses/NOTICE.md)。[LICENSE-SCOPE.md](LICENSE-SCOPE.md) 区分软件、字体和图稿。此仓库排除权利未证的原始图标，使用明确列出的原创 CC BY 4.0 几何占位图；私人打包仍保留原图，不能据此公开它。

来源历史及验证范围见 [PUBLICATION.md](PUBLICATION.md)。
