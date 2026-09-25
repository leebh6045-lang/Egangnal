#!/bin/zsh
# 把 design-assets 里的图标源 SVG 渲染成 AppIcon.appiconset 需要的全部尺寸。
# 优先用 rsvg-convert 逐尺寸直接矢量渲染；没有时退回 Chrome 无头截图 + sips 缩放。
set -euo pipefail

ROOT="${0:A:h:h}"
SVG="$ROOT/design-assets/app-icon/Egangnal-AppIcon-Butterfly.svg"
PREVIEW="$ROOT/design-assets/app-icon/Egangnal-AppIcon-Butterfly-1024.png"
ICONSET="$ROOT/Egangnal/Assets.xcassets/AppIcon.appiconset"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 文件名 → 像素边长，与 Contents.json 一一对应
typeset -A SIZES=(
  icon_16x16.png 16        icon_16x16@2x.png 32
  icon_32x32.png 32        icon_32x32@2x.png 64
  icon_128x128.png 128     icon_128x128@2x.png 256
  icon_256x256.png 256     icon_256x256@2x.png 512
  icon_512x512.png 512     icon_512x512@2x.png 1024
)

if command -v rsvg-convert >/dev/null; then
  for name px in ${(kv)SIZES}; do
    rsvg-convert -w "$px" -h "$px" "$SVG" -o "$ICONSET/$name"
  done
elif [[ -x "$CHROME" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --window-size=1024,1024 \
    --screenshot="$tmp/1024.png" "file://$SVG" >/dev/null 2>&1
  for name px in ${(kv)SIZES}; do
    sips -z "$px" "$px" "$tmp/1024.png" --out "$ICONSET/$name" >/dev/null
  done
else
  echo "需要 rsvg-convert（brew install librsvg）或 Google Chrome 才能渲染 SVG" >&2
  exit 1
fi

cp "$ICONSET/icon_512x512@2x.png" "$PREVIEW"
echo "已更新 $ICONSET 与 $PREVIEW"
