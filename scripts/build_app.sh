#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_VERSION="${APP_MONITOR_VERSION:-${2:-1.0}}"
APP_BUILD="${APP_MONITOR_BUILD:-${3:-1}}"
APPCAST_URL="${APP_MONITOR_APPCAST_URL:-https://github.com/jcranokc/app-monitor/releases/latest/download/appcast.xml}"
SIGN_IDENTITY="${APP_MONITOR_SIGN_IDENTITY:--}"
SIGN_ENTITLEMENTS="${APP_MONITOR_ENTITLEMENTS:-}"
HARDENED_RUNTIME="${APP_MONITOR_HARDENED_RUNTIME:-auto}"
TIMESTAMP_SIGNATURE="${APP_MONITOR_TIMESTAMP_SIGNATURE:-auto}"
PRODUCT_DIR="$ROOT_DIR/build"
APP_NAME="App Monitor"
APP_DIR="$PRODUCT_DIR/$APP_NAME.app"
BINARY_NAME="AppMonitor"
ASKPASS_BINARY_NAME="AppMonitorAskpass"

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

should_enable() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

using_distribution_identity() {
  [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]
}

APP_VERSION_XML="$(xml_escape "$APP_VERSION")"
APP_BUILD_XML="$(xml_escape "$APP_BUILD")"
APPCAST_URL_XML="$(xml_escape "$APPCAST_URL")"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BUILD_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BUILT_BINARY="$BUILD_BIN_DIR/$BINARY_NAME"
BUILT_ASKPASS_BINARY="$BUILD_BIN_DIR/$ASKPASS_BINARY_NAME"
if [[ ! -x "$BUILT_ASKPASS_BINARY" ]]; then
  echo "Missing secure Homebrew askpass helper at $BUILT_ASKPASS_BINARY" >&2
  exit 1
fi
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Helpers"
cp "$BUILT_BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BUILT_ASKPASS_BINARY" "$APP_DIR/Contents/Helpers/$ASKPASS_BINARY_NAME"
chmod 755 "$APP_DIR/Contents/Helpers/$ASKPASS_BINARY_NAME"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorIcon.icns" "$APP_DIR/Contents/Resources/AppMonitorIcon.icns"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorAppIcon.png" "$APP_DIR/Contents/Resources/AppMonitorAppIcon.png"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorLogo.png" "$APP_DIR/Contents/Resources/AppMonitorLogo.png"

while IFS= read -r resource_bundle; do
  cp -R "$resource_bundle" "$APP_DIR/Contents/Resources/"
done < <(find "$BUILD_BIN_DIR" -maxdepth 1 -type d -name "*.bundle" -print)

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>App Monitor</string>
  <key>CFBundleIconFile</key>
  <string>AppMonitorIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.jacob.appmonitor</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>App Monitor</string>
  <key>CFBundleDisplayName</key>
  <string>App Monitor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION_XML}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD_XML}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSUIElement</key>
  <true/>
  <key>SUFeedURL</key>
  <string>${APPCAST_URL_XML}</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>App Monitor uses macOS authorization only when you request an update action that needs administrator approval.</string>
  <key>NSDesktopFolderUsageDescription</key>
  <string>App Monitor checks app-related files only when you request storage, cleanup, or uninstall analysis.</string>
  <key>NSDocumentsFolderUsageDescription</key>
  <string>App Monitor checks app-related files only when you request storage, cleanup, or uninstall analysis.</string>
  <key>NSDownloadsFolderUsageDescription</key>
  <string>App Monitor checks app-related downloads only when you request storage, cleanup, or uninstall analysis.</string>
  <key>NSNetworkVolumesUsageDescription</key>
  <string>App Monitor checks app-related files on network volumes only when you include those locations in analysis.</string>
  <key>NSRemovableVolumesUsageDescription</key>
  <string>App Monitor checks app-related files on removable volumes only when you include those locations in analysis.</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Jacob Crandall</string>
</dict>
</plist>
PLIST

codesign_args=(--force --deep --sign "$SIGN_IDENTITY")

if [[ -n "$SIGN_ENTITLEMENTS" ]]; then
  codesign_args+=(--entitlements "$SIGN_ENTITLEMENTS")
fi

if [[ "$HARDENED_RUNTIME" == "auto" ]]; then
  if using_distribution_identity; then
    codesign_args+=(--options runtime)
  fi
elif should_enable "$HARDENED_RUNTIME"; then
  codesign_args+=(--options runtime)
fi

if [[ "$TIMESTAMP_SIGNATURE" == "auto" ]]; then
  if using_distribution_identity; then
    codesign_args+=(--timestamp)
  fi
elif should_enable "$TIMESTAMP_SIGNATURE"; then
  codesign_args+=(--timestamp)
fi

codesign "${codesign_args[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_DIR" >/dev/null
echo "$APP_DIR"
