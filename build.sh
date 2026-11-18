#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

APP=build/FanControl.app
ICNS=Resources/AppIcon.icns
ICNS_EMBER=Resources/AppIcon-Ember.icns

make_icon() {
  local tool=$1 out=$2
  echo "→ иконка $out"
  local tmp; tmp=$(mktemp -d)
  swiftc -O "$tool" -o "$tmp/makeicon"
  "$tmp/makeicon" "$tmp/icon.png"
  local set="$tmp/AppIcon.iconset"; mkdir "$set"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$tmp/icon.png" --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$tmp/icon.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$out"
  rm -rf "$tmp"
}

[[ "${1:-}" == "--icon" || ! -f "$ICNS" ]] && make_icon Tools/MakeIcon.swift "$ICNS"
[[ "${1:-}" == "--icon" || ! -f "$ICNS_EMBER" ]] && make_icon Tools/MakeIconEmber.swift "$ICNS_EMBER"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "let buildID = \"$(date +%Y%m%d%H%M%S)\"" > Shared/BuildInfo.swift

echo "→ помощник fancontrold"
swiftc -O Shared/*.swift Daemon/main.swift -framework IOKit \
  -o "$APP/Contents/Resources/fancontrold"

echo "→ приложение FanControl"
swiftc -O -parse-as-library Shared/*.swift App/*.swift \
  -framework IOKit -framework SwiftUI -framework AppKit \
  -target arm64-apple-macos13 \
  -o "$APP/Contents/MacOS/FanControl"

cp Resources/Info.plist "$APP/Contents/"
cp Resources/com.fancontrol.daemon.plist "$ICNS" "$ICNS_EMBER" "$APP/Contents/Resources/"
codesign --force --sign - "$APP/Contents/Resources/fancontrold"
codesign --force --sign - "$APP"

echo "Готово: $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x FanControl 2>/dev/null || true
  rm -rf /Applications/FanControl.app
  cp -R "$APP" /Applications/
  echo "Установлено: /Applications/FanControl.app"
  open /Applications/FanControl.app
fi
