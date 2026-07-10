# Releasing App Monitor Updates

App Monitor update discovery is wired through the app's existing direct-download update provider:

- `scripts/build_app.sh` writes `CFBundleShortVersionString`, `CFBundleVersion`, and `SUFeedURL` into the packaged app.
- `scripts/build_app.sh` signs ad hoc by default. Set `APP_MONITOR_SIGN_IDENTITY` to a Developer ID Application identity to sign with hardened runtime and a timestamp.
- `scripts/package_release.sh` builds `build/App Monitor.app`, creates `build/release/App-Monitor-Beta.zip`, creates `build/release/App-Monitor-Beta.dmg` with the App Monitor volume icon, and generates `build/release/appcast.xml`.
- `gh release create` publishes the zip, DMG, appcast, and checksum file to a GitHub Release.
- The app checks `https://github.com/jcranokc/app-monitor/releases/latest/download/appcast.xml` during update scans and opens the release asset when a newer version is available.

## Local Verification

Build and test the app:

```bash
./scripts/ci
```

Build release artifacts locally:

```bash
./scripts/package_release.sh 1.2.0 3
```

Inspect the generated metadata:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "build/App Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "build/App Monitor.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "build/App Monitor.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "build/App Monitor.app"
hdiutil verify "build/release/App-Monitor-Beta.dmg"
cat build/release/appcast.xml
```

## Local DMG Packaging

The local packaging command writes:

- `build/release/App-Monitor-Beta.zip`
- `build/release/App-Monitor-Beta.dmg`
- `build/release/appcast.xml`
- `build/release/SHA256SUMS`

The DMG contains `App Monitor.app` plus an `/Applications` symlink for drag-and-drop install. It also embeds `AppMonitorIcon.icns` as the Finder volume icon.

## Homebrew Beta Cask

App Monitor is a macOS GUI app, so Homebrew distribution should use a cask, not a formula. Start with a personal tap instead of the upstream Homebrew cask repository while the app is in beta.

Use versioned beta release tags so Homebrew can upgrade predictably. For app version `1.2.0` and build `3`, use tag `v1.2.0-beta.3`:

```bash
VERSION=1.2.0
BUILD=3
TAG="v${VERSION}-beta.${BUILD}"

APP_MONITOR_TAG="$TAG" ./scripts/package_release.sh "$VERSION" "$BUILD"
gh release create "$TAG" \
  build/release/App-Monitor-Beta.zip \
  build/release/App-Monitor-Beta.dmg \
  build/release/appcast.xml \
  build/release/SHA256SUMS \
  --target main \
  --title "App Monitor ${VERSION} beta ${BUILD}" \
  --notes "App Monitor beta release."
```

Then generate the Homebrew cask:

```bash
./scripts/generate_homebrew_beta_cask.sh "$VERSION" "$BUILD"
```

The generated file is written to:

```text
build/homebrew/Casks/app-monitor@beta.rb
```

Create a tap once:

```bash
brew tap-new jcranokc/homebrew-tap
```

Copy the generated cask into the tap and test it:

```bash
TAP_ROOT="$(brew --repository jcranokc/tap)"
mkdir -p "$TAP_ROOT/Casks"
cp build/homebrew/Casks/app-monitor@beta.rb "$TAP_ROOT/Casks/app-monitor@beta.rb"

brew audit --cask --strict --skip-style jcranokc/tap/app-monitor@beta
brew style --cask jcranokc/tap/app-monitor@beta
brew install --cask jcranokc/tap/app-monitor@beta
```

After the local install works, commit and push the tap repository. Users can install the beta with:

```bash
brew install --cask jcranokc/tap/app-monitor@beta
```

For each new beta, publish a new `v<version>-beta.<build>` GitHub release, regenerate the cask so its `version` and `sha256` change, then commit the updated cask in the tap. This is what lets `brew upgrade` pick up the beta.

## Developer ID Signing And Notarization

An ad-hoc signed app will still trigger Gatekeeper warnings after download. For public distribution outside the Mac App Store, use a paid Apple Developer account with a Developer ID Application certificate, hardened runtime, and notarization.

Check available signing identities:

```bash
security find-identity -v -p codesigning
```

The identity should look like:

```text
Developer ID Application: Your Name (TEAMID)
```

Store notarization credentials in Keychain. Prefer a Keychain profile so scripts never contain your Apple ID password or API key:

```bash
xcrun notarytool store-credentials "app-monitor-notary" --apple-id "you@example.com" --team-id "TEAMID"
```

Or store App Store Connect API key credentials:

```bash
xcrun notarytool store-credentials "app-monitor-notary" --key /path/to/AuthKey_ABC123.p8 --key-id ABC123DEFG --issuer 00000000-0000-0000-0000-000000000000
```

Build, sign, notarize, and staple:

```bash
APP_MONITOR_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_MONITOR_NOTARY_PROFILE="app-monitor-notary" \
./scripts/package_release.sh 1.2.0 3
```

The script notarizes the zip, staples the app, recreates the zip, creates a DMG, notarizes the DMG, and staples the DMG.

Verify the result:

```bash
codesign --verify --deep --strict --verbose=2 "build/App Monitor.app"
spctl --assess --type execute --verbose=4 "build/App Monitor.app"
xcrun stapler validate "build/App Monitor.app"
xcrun stapler validate "build/release/App-Monitor-Beta.dmg"
hdiutil verify "build/release/App-Monitor-Beta.dmg"
```

## Privacy And Gatekeeper Notes

There are two different macOS warning systems to account for:

- Gatekeeper flags downloaded apps that are unsigned, ad-hoc signed, modified after signing, or not notarized. Developer ID signing plus notarization is the legitimate fix.
- Privacy/TCC prompts protect folders, automation, screen recording, Full Disk Access, and other sensitive resources. These prompts cannot and should not be bypassed. App Monitor includes purpose strings for user-requested file analysis and administrator-authorized update actions, but users may still need to grant permission in System Settings depending on what they scan.

App Monitor should avoid scanning protected locations until the user starts a storage, cleanup, uninstall, or update action. If macOS blocks a location, guide the user to System Settings > Privacy & Security and keep the app functional with partial scan results.

## Publishing A Future Update

After you make a change and commit it:

```bash
git push origin main
APP_MONITOR_TAG="v1.2.0-beta.3" ./scripts/package_release.sh 1.2.0 3
gh release create v1.2.0-beta.3 \
  build/release/App-Monitor-Beta.zip \
  build/release/App-Monitor-Beta.dmg \
  build/release/appcast.xml \
  build/release/SHA256SUMS \
  --target main \
  --title "App Monitor 1.2.0 beta 3" \
  --notes "App Monitor beta release."
```

Use a new version tag every time you want installed copies of App Monitor to see an update. Ordinary pushes to `main` do not publish an app update by themselves.

## Current Distribution Limits

The release package signs the app ad hoc unless `APP_MONITOR_SIGN_IDENTITY` and `APP_MONITOR_NOTARY_PROFILE` are provided. That is fine for local/private use, but macOS Gatekeeper can warn on downloaded builds because the app is not Developer ID signed or notarized. For wider distribution, add Developer ID signing and notarization before relying on this as a public auto-update channel.
