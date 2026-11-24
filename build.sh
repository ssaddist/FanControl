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

if [[ "${1:-}" == "--dmg" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
  DMG="build/FanControl-$VERSION.dmg"
  echo "→ образ $DMG"
  tmp=$(mktemp -d)
  stage="$tmp/stage"
  mkdir -p "$stage/.background"
  cp -R "$APP" "$stage/"
  ln -s /Applications "$stage/Applications"
  swiftc -O Tools/MakeDMGBackground.swift -o "$tmp/makebg"
  "$tmp/makebg" "$tmp"
  tiffutil -cathidpicheck "$tmp/bg.png" "$tmp/bg@2x.png" -out "$stage/.background/bg.tiff" >/dev/null 2>&1
  hdiutil detach /Volumes/FanControl -quiet 2>/dev/null || true
  hdiutil create -quiet -srcfolder "$stage" -volname FanControl -fs HFS+ -format UDRW -ov "$tmp/rw.dmg"
  hdiutil attach -quiet -readwrite -noverify -noautoopen "$tmp/rw.dmg"
  osascript <<'EOF' || echo "  (не удалось оформить окно, образ будет без фона)"
tell application "Finder"
  tell disk "FanControl"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set sidebar width of container window to 0
    set bounds of container window to {200, 120, 800, 505}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:bg.tiff"
    set extension hidden of item "FanControl.app" to true
    set position of item "FanControl.app" of container window to {160, 170}
    set position of item "Applications" of container window to {440, 170}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
  cp "$ICNS_EMBER" /Volumes/FanControl/.VolumeIcon.icns
  SetFile -a C /Volumes/FanControl
  sync
  hdiutil detach -quiet /Volumes/FanControl
  rm -f "$DMG"
  hdiutil convert -quiet "$tmp/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"
  rm -rf "$tmp"
  echo "Готово: $DMG"
fi

if [[ "${1:-}" == "--install" ]]; then
  pkill -x FanControl 2>/dev/null || true
  rm -rf /Applications/FanControl.app
  cp -R "$APP" /Applications/
  echo "Установлено: /Applications/FanControl.app"
  open /Applications/FanControl.app
fi
