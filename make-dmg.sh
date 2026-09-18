#!/usr/bin/env bash
# CrossTerminal DMG 打包脚本
# 功能：交叉编译 universal 二进制(arm64 + x86_64) -> 组装 .app -> 签名 -> hdiutil 制作 dmg -> (可选)公证
# 用法：./make-dmg.sh [版本号]
#   版本号默认取环境变量 GITHUB_REF_NAME（形如 v1.0.0），也可手动传参；v 前缀会自动去掉。
#   产物：build/CrossTerminal-<版本>.dmg
#
# 签名与公证（CI 发布用，对应 GitHub Secrets）：
#   - 证书：BUILD_CERTIFICATE_BASE64(p12 的 base64) + P12_PASSWORD(解 p12) + KEYCHAIN_PASSWORD(CI 临时钥匙串)，
#     由 workflow 的「Install Apple signing certificate」步骤导入钥匙串。
#   - 证书名(SIGN_ID)无需配置：脚本自动从已安装钥匙串选取 Developer ID Application 身份。
#   - 公证：APPLE_ID + APPLE_APP_PASSWORD(app 专用密码) + APPLE_TEAM_ID，交给 `xcrun notarytool`。
#   - 以上变量均未设置时，自动回退 ad-hoc 签名、跳过公证（便于本地调试）。
#
# 设计取舍：
#   - 用 hdiutil 而非 create-dmg：前者系统自带、零依赖，且在 CI（无 GUI）环境稳定可用。
#   - universal 二进制：SwiftPM 分别按 arm64 / x86_64 编译，再用 lipo 合并。
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME=CrossTerminal
VERSION="${1:-${GITHUB_REF_NAME:-dev}}"
VERSION="${VERSION#v}"   # 去掉可能的 v 前缀

STAGE=".build/dmg-stage"
APP="$STAGE/$APP_NAME.app"
DMG="build/$APP_NAME-$VERSION.dmg"

# 签名标识：优先用环境变量 SIGN_ID；否则从已安装钥匙串自动选取 Developer ID Application 证书
SIGN_ID="${SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')
fi

echo "==> [1/6] 交叉编译 universal 二进制 (arm64 + x86_64)"
swift build -c release --arch arm64   --build-path .build/arm64
swift build -c release --arch x86_64  --build-path .build/x86_64

ARM_BIN=".build/arm64/release/$APP_NAME"
X86_BIN=".build/x86_64/release/$APP_NAME"
UNI=".build/release/$APP_NAME-universal"
lipo -create -output "$UNI" "$ARM_BIN" "$X86_BIN"
echo "    合并后架构: $(lipo -info "$UNI" | sed 's/.*://')"

echo "==> [2/6] 组装 .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$UNI"                          "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist           "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns         "$APP/Contents/Resources/AppIcon.icns"

echo "==> [3/6] 代码签名"
if [ -n "$SIGN_ID" ]; then
  echo "    使用 Developer ID 签名: $SIGN_ID"
  # --options runtime 开启 hardened runtime（公证必需）；--timestamp 联网时间戳
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$APP"
else
  echo "    未找到 Developer ID 证书，回退 ad-hoc 签名（仅本地/调试用）"
  codesign --force --deep --sign - "$APP"
fi

echo "==> [4/6] 准备 dmg 暂存区（含 Applications 快捷方式，便于拖拽安装）"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> [5/6] 制作 dmg (hdiutil, UDZO 压缩只读)"
mkdir -p build
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> [6/6] 公证 (使用 Apple ID + app-specific 密码)"
# 公证前提：必须同时具备 Developer ID 签名(SIGN_ID) 与 Apple ID 三件套；
# 仅配置了公证凭证但没有有效 Developer ID 证书时，ad-hoc 签名无法公证，给出明确提示并跳过。
if [ -z "$SIGN_ID" ]; then
  echo "    未检测到 Developer ID 签名标识(SIGN_ID)，无法公证（需先在 CI 配置 BUILD_CERTIFICATE_BASE64 等证书 Secrets）"
  echo "    跳过 notarization"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
  echo "    使用 Apple ID + app-specific 密码公证"
  xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
  xcrun stapler staple "$DMG"
  echo "    公证票据已 staple 到 dmg"
else
  echo "    未配置公证凭证(APPLE_ID/APPLE_APP_PASSWORD/APPLE_TEAM_ID)，跳过 notarization"
fi

echo "完成: $DMG ($(du -h "$DMG" | cut -f1))"
