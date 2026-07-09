# Releasing App Monitor Updates

App Monitor update discovery is wired through the app's existing direct-download update provider:

- `scripts/build_app.sh` writes `CFBundleShortVersionString`, `CFBundleVersion`, and `SUFeedURL` into the packaged app.
- `scripts/build_app.sh` signs ad hoc by default. Set `APP_MONITOR_SIGN_IDENTITY` to a Developer ID Application identity to sign with hardened runtime and a timestamp.
- `scripts/package_release.sh` builds `build/App Monitor.app`, creates `build/release/App-Monitor-<version>.zip`, creates `build/release/App-Monitor-Beta.dmg` with the App Monitor volume icon, and generates `build/release/appcast.xml`.
- `gh release create` publishes the zip, DMG, appcast, and checksum file to a GitHub Release.
- The app checks `https://github.com/jcranokc/app-monitor/releases/latest/download/appcast.xml` during update scans and opens the release asset when a newer version is available.

## Local Verification

Build and test the app:

```bash
./scripts/ci
```

Build release artifacts locally:

```bash
./scripts/package_release.sh 1.1.0 2
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

- `build/release/App-Monitor-<version>.zip`
- `build/release/App-Monitor-Beta.dmg`
- `build/release/appcast.xml`
- `build/release/SHA256SUMS`

The DMG contains `App Monitor.app` plus an `/Applications` symlink for drag-and-drop install. It also embeds `AppMonitorIcon.icns` as the Finder volume icon.

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
./scripts/package_release.sh 1.1.0 2
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
./scripts/package_release.sh 1.1.0 2
gh release create v1.1.0 \
  build/release/App-Monitor-1.1.0.zip \
  build/release/App-Monitor-Beta.dmg \
  build/release/appcast.xml \
  build/release/SHA256SUMS \
  --target main \
  --title "App Monitor 1.1.0" \
  --notes "App Monitor 1.1.0 release."
```

Use a new version tag every time you want installed copies of App Monitor to see an update. Ordinary pushes to `main` do not publish an app update by themselves.

## Current Distribution Limits

The release package signs the app ad hoc unless `APP_MONITOR_SIGN_IDENTITY` and `APP_MONITOR_NOTARY_PROFILE` are provided. That is fine for local/private use, but macOS Gatekeeper can warn on downloaded builds because the app is not Developer ID signed or notarized. For wider distribution, add Developer ID signing and notarization before relying on this as a public auto-update channel.
