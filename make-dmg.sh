#!/usr/bin/env bash
# CrossTerminal DMG 打包脚本
# 功能：交叉编译 universal 二进制(arm64 + x86_64) -> 组装 .app -> ad-hoc 签名 -> hdiutil 制作 dmg
# 用法：./make-dmg.sh [版本号]
#   版本号默认取环境变量 GITHUB_REF_NAME（形如 v1.0.0），也可手动传参；v 前缀会自动去掉。
#   产物：build/CrossTerminal-<版本>.dmg
#
# 设计取舍：
#   - 用 hdiutil 而非 create-dmg：前者系统自带、零依赖，且在 CI（无 GUI）环境稳定可用；
#     create-dmg 依赖 brew 安装且需要 Finder 图形界面设置窗口布局，CI 上不可靠。
#   - universal 二进制：SwiftPM 分别按 arm64 / x86_64 编译，再用 lipo 合并，
#     让 Apple 芯片与 Intel Mac 用户都能直接下载使用。
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME=CrossTerminal
# 版本号：优先用传入参数，其次用 CI 注入的 GITHUB_REF_NAME，最后兜底 dev
VERSION="${1:-${GITHUB_REF_NAME:-dev}}"
VERSION="${VERSION#v}"   # 去掉可能的 v 前缀

STAGE=".build/dmg-stage"          # dmg 暂存区（在 .build/ 内，已被 .gitignore 忽略）
APP="$STAGE/$APP_NAME.app"
DMG="build/$APP_NAME-$VERSION.dmg"

echo "==> [1/5] 交叉编译 universal 二进制 (arm64 + x86_64)"
# 两个架构分别编译到独立的 build-path，避免互相覆盖
swift build -c release --arch arm64   --build-path .build/arm64
swift build -c release --arch x86_64  --build-path .build/x86_64

ARM_BIN=".build/arm64/release/$APP_NAME"
X86_BIN=".build/x86_64/release/$APP_NAME"
UNI=".build/release/$APP_NAME-universal"
lipo -create -output "$UNI" "$ARM_BIN" "$X86_BIN"
echo "    合并后架构: $(lipo -info "$UNI" | sed 's/.*://')"

echo "==> [2/5] 组装 .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$UNI"                              "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist               "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns             "$APP/Contents/Resources/AppIcon.icns"
# ad-hoc 签名：无开发者证书也能在本机/用户机运行（Gatekeeper 首次会拦截，README 已说明解法）
codesign --force --deep --sign - "$APP"

echo "==> [3/5] 准备 dmg 暂存区（含 Applications 快捷方式，便于拖拽安装）"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> [4/5] 制作 dmg (hdiutil, UDZO 压缩只读)"
mkdir -p build
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> [5/5] 完成"
echo "产物: $DMG ($(du -h "$DMG" | cut -f1))"
