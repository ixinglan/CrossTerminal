# CrossTerminal

在访达里一键把「当前文件夹」打开到你常用的终端。无 Dock 图标、无菜单栏，轻量、安静，用完即退。

## 为什么做

在访达里翻文件时，经常需要在这个目录里敲命令：复制路径、打开终端、再 `cd` 一遍——步骤又碎又烦。
CrossTerminal 把这个动作压成一步：把一个小按钮钉在访达工具栏上，点一下，当前所在的文件夹就直接在终端里打开。

它刻意做成一个「隐形」的小工具：

- 不占 Dock（没有常驻图标）；
- 没有菜单栏图标；
- 不后台常驻，点完就退。

你几乎感觉不到它的存在，直到某天你习惯性点了一下、终端唰地打开。

## 功能介绍

- **访达工具栏一键打开**：把应用拖进访达工具栏，点一下即在终端中打开当前所在目录。
- **无 Dock / 无菜单栏**：以辅助应用（agent）方式运行，不打扰你的桌面。
- **可选终端**：首次运行让你从系统已安装的终端里挑一个，默认「系统终端」；之后想换随时换。
- **科幻极简图标**：深空渐变 + 霓虹终端提示符，年轻、克制。

## 用法指引

### 1. 构建（开发者）

需要本机装好 Xcode 命令行工具（含 Swift 6）：

```bash
./build.sh
```

产物在 `build/CrossTerminal.app`（已自动签名，可直接在本机运行）。

> 当前在 Apple 芯片 Mac 上编出的是 arm64 版本；要在 Intel Mac 上用，在对应机器重新 `./build.sh` 即可。

### 2. 首次设置

双击 `CrossTerminal.app`，在弹窗里选好默认终端 → 保存。
（这一步会在 `~/Library/Application Support/CrossTerminal/config.json` 写入配置。）

### 3. 装到访达工具栏

保持 **⌘** 按住，把 `CrossTerminal.app` 从访达拖到窗口工具栏上松手。

### 4. 日常使用

在访达里进入任意文件夹，点一下工具栏上的 CrossTerminal 图标即可。

> 首次运行时 macOS 会请求「控制 Finder / Terminal」的自动化权限，允许即可——这是读取目录、在终端里执行 `cd` 所必需的。

### 想换终端？

编辑配置文件即可，无需重装：

```
~/Library/Application Support/CrossTerminal/config.json
```

把 `terminalId` 改成别的（可选值见下方「技术相关」）。

## 技术相关（给想魔改的人）

### 技术栈

Swift 6 + SwiftUI + AppKit，SwiftPM 可执行目标，手动打包成 `.app`。

### 目录结构

```
CrossTerminal/
├── Package.swift              # SwiftPM 可执行目标
├── build.sh                   # 编译 + 打包 .app + 签名
├── Resources/
│   ├── Info.plist             # LSUIElement=true 等
│   ├── AppIcon.svg            # 图标源文件
│   └── AppIcon.icns           # 编进 .app 的图标
└── Sources/
    ├── main.swift             # NSApplication 入口（agent 模式）
    ├── AppDelegate.swift      # 启动逻辑：设置 or 打开终端
    ├── Config.swift           # 配置文件读写
    ├── TerminalManager.swift  # 终端检测与打开策略
    ├── FinderBridge.swift     # 读取访达当前目录
    └── SettingsView.swift     # 首次设置窗口
```

### 工作原理

- 应用以 `LSUIElement=true`（代码里 `setActivationPolicy(.accessory)`）运行，故无 Dock / 菜单栏。
- 从访达工具栏点击 → 启动应用 → 通过 AppleScript 读取访达最前方窗口所在目录 → 调用所选终端的打开策略（`cd` 到该目录）→ 应用自动退出。
- 首次（无配置）则弹出 SwiftUI 设置窗口，选好终端后写入配置文件。

### 可选终端 id

内置：`terminal`(系统终端,默认)、`iterm`、`warp`、`kitty`、`alacritty`、`ghostty`、`hyper`、`tabby`、`wezterm`。

### 添加自定义终端

在 `config.json` 里追加 `customTerminals`，用 `{PATH}` 占位当前目录：

```json
{
  "terminalId": "myterm",
  "customTerminals": [
    {
      "id": "myterm",
      "name": "我的终端",
      "appName": "MyTerm",
      "openCommand": "--working-directory {PATH}"
    }
  ]
}
```

`openCommand` 会作为 `open -a <appName> --args <openCommand>` 的参数执行，`{PATH}` 被替换为实际目录。

### 平台要求

macOS 14.0+。
