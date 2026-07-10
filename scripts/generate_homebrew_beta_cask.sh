#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${APP_MONITOR_VERSION:-}}"
BUILD_NUMBER="${2:-${APP_MONITOR_BUILD:-}}"
OUTPUT_ROOT="${3:-${APP_MONITOR_HOMEBREW_OUTPUT_ROOT:-$ROOT_DIR/build/homebrew}}"
REPOSITORY="${APP_MONITOR_REPOSITORY:-jcranokc/app-monitor}"
DMG_NAME="${APP_MONITOR_DMG_NAME:-App-Monitor-Beta.dmg}"
DMG_PATH="${APP_MONITOR_DMG_PATH:-$ROOT_DIR/build/release/$DMG_NAME}"
CASK_PATH="$OUTPUT_ROOT/Casks/app-monitor@beta.rb"

usage() {
  echo "Usage: $0 <version> <build-number> [output-root]" >&2
  echo "Example: $0 1.2.0 3" >&2
}

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG at $DMG_PATH" >&2
  echo "Build it first with:" >&2
  echo "  APP_MONITOR_TAG=\"v$VERSION-beta.$BUILD_NUMBER\" ./scripts/package_release.sh \"$VERSION\" \"$BUILD_NUMBER\"" >&2
  exit 1
fi

DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

mkdir -p "$(dirname "$CASK_PATH")"

cat > "$CASK_PATH" <<RB
cask "app-monitor@beta" do
  version "$VERSION,$BUILD_NUMBER"
  sha256 "$DMG_SHA256"

  url "https://github.com/$REPOSITORY/releases/download/v#{version.csv.first}-beta.#{version.csv.second}/$DMG_NAME"
  name "App Monitor Beta"
  desc "App usage, cleanup, update, and uninstall dashboard"
  homepage "https://github.com/$REPOSITORY"

  livecheck do
    url "https://github.com/$REPOSITORY"
    regex(/^v?(\\d+(?:\\.\\d+)+)-beta[._-]?(\\d+)$/i)
    strategy :github_releases do |json, regex|
      json.filter_map do |release|
        next if release["draft"]

        match = release["tag_name"]&.match(regex)
        next if match.blank?

        "#{match[1]},#{match[2]}"
      end
    end
  end

  depends_on macos: :sonoma

  app "App Monitor.app"

  uninstall quit: "com.jacob.appmonitor"

  zap trash: [
    "~/Library/Application Support/App Monitor",
    "~/Library/Caches/com.jacob.appmonitor",
    "~/Library/HTTPStorages/com.jacob.appmonitor",
    "~/Library/Preferences/com.jacob.appmonitor.plist",
    "~/Library/Saved Application State/com.jacob.appmonitor.savedState",
  ]
end
RB

echo "$CASK_PATH"
