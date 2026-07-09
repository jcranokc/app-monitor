#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${APP_MONITOR_VERSION:-}}"
BUILD_NUMBER="${2:-${APP_MONITOR_BUILD:-}}"
REPOSITORY="${APP_MONITOR_REPOSITORY:-jcranokc/app-monitor}"

if [[ -z "$VERSION" ]]; then
  if VERSION_FROM_TAG="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null)"; then
    VERSION="${VERSION_FROM_TAG#v}"
  else
    echo "Usage: $0 <version> [build-number]" >&2
    exit 2
  fi
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)"
fi

TAG_NAME="${APP_MONITOR_TAG:-v$VERSION}"
APPCAST_URL="${APP_MONITOR_APPCAST_URL:-https://github.com/$REPOSITORY/releases/latest/download/appcast.xml}"
RELEASE_BASE_URL="${APP_MONITOR_RELEASE_BASE_URL:-https://github.com/$REPOSITORY/releases/download/$TAG_NAME}"
RELEASE_DIR="$ROOT_DIR/build/release"
APP_DIR="$ROOT_DIR/build/App Monitor.app"
ZIP_NAME="App-Monitor-$VERSION.zip"
DMG_NAME="${APP_MONITOR_DMG_NAME:-App-Monitor-Beta.dmg}"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"
SHA_PATH="$RELEASE_DIR/SHA256SUMS"
NOTARY_PROFILE="${APP_MONITOR_NOTARY_PROFILE:-}"
SIGN_IDENTITY="${APP_MONITOR_SIGN_IDENTITY:-}"
DMG_ICON="$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorIcon.icns"

cd "$ROOT_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

APP_MONITOR_VERSION="$VERSION" \
APP_MONITOR_BUILD="$BUILD_NUMBER" \
APP_MONITOR_APPCAST_URL="$APPCAST_URL" \
  "$ROOT_DIR/scripts/build_app.sh" release >/dev/null

create_zip() {
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
}

create_dmg() {
  local staging_dir="$RELEASE_DIR/dmg-root"
  rm -rf "$staging_dir" "$DMG_PATH"
  mkdir -p "$staging_dir"
  ditto "$APP_DIR" "$staging_dir/App Monitor.app"
  ln -s /Applications "$staging_dir/Applications"

  cp "$DMG_ICON" "$staging_dir/.VolumeIcon.icns"
  chmod 644 "$staging_dir/.VolumeIcon.icns"
  SetFile -t icns -c icnC "$staging_dir/.VolumeIcon.icns"
  SetFile -a C "$staging_dir"

  diskutil image create from \
    --format UDZO \
    --volumeName "App Monitor $VERSION" \
    "$staging_dir" \
    "$DMG_PATH" >/dev/null
  rm -rf "$staging_dir"

  if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH" >/dev/null
    codesign --verify --verbose=2 "$DMG_PATH" >/dev/null
  fi
}

notarize_archive() {
  local archive_path="$1"
  xcrun notarytool submit "$archive_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
}

if [[ -n "$NOTARY_PROFILE" && ( -z "$SIGN_IDENTITY" || "$SIGN_IDENTITY" == "-" ) ]]; then
  echo "APP_MONITOR_NOTARY_PROFILE requires APP_MONITOR_SIGN_IDENTITY with a Developer ID Application identity." >&2
  exit 2
fi

create_zip

if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize_archive "$ZIP_PATH"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  create_zip
fi

create_dmg

if [[ -n "$NOTARY_PROFILE" ]]; then
  notarize_archive "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

ZIP_SIZE="$(stat -f%z "$ZIP_PATH" 2>/dev/null || stat -c%s "$ZIP_PATH")"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
DOWNLOAD_URL="$RELEASE_BASE_URL/$ZIP_NAME"
RELEASE_NOTES_URL="https://github.com/$REPOSITORY/releases/tag/$TAG_NAME"
PUB_DATE="$(LC_ALL=C TZ=GMT date '+%a, %d %b %Y %H:%M:%S %z')"

cat > "$APPCAST_PATH" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>App Monitor Updates</title>
    <link>https://github.com/$REPOSITORY/releases</link>
    <description>App Monitor release feed.</description>
    <item>
      <title>App Monitor $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>
      <enclosure
        url="$DOWNLOAD_URL"
        sparkle:version="$BUILD_NUMBER"
        sparkle:shortVersionString="$VERSION"
        sparkle:minimumSystemVersion="14.0"
        sparkle:sha256="$ZIP_SHA256"
        length="$ZIP_SIZE"
        type="application/zip" />
    </item>
  </channel>
</rss>
XML

cat > "$SHA_PATH" <<EOF
$ZIP_SHA256  $ZIP_NAME
$DMG_SHA256  $DMG_NAME
EOF

echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$APPCAST_PATH"
echo "$SHA_PATH"
