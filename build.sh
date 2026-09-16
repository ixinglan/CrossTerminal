#!/usr/bin/env bash
# CrossTerminal 构建脚本：编译 -> 打包 .app -> ad-hoc 签名
# 用法：./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME=CrossTerminal
BUILD_DIR=build
APP="$BUILD_DIR/$APP_NAME.app"
BIN=".build/release/$APP_NAME"

echo "==> [1/4] 编译 (swift build -c release)"
swift build -c release

echo "==> [2/4] 组装 .app 包"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> [3/4] ad-hoc 签名（本机运行用，无需开发者证书）"
codesign --force --deep --sign - "$APP"

echo "==> [4/4] 完成"
echo "产物: $APP"
echo "首次使用：双击打开完成终端选择；然后按住 ⌘ 将其拖入访达工具栏。"
