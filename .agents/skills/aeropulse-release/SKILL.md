---
name: aeropulse-release
description: Use when building, signing, or releasing new versions of AeroPulse (Flux-MacOSNetworkFanSpeed), generating signed Sparkle appcasts, creating GitHub releases, or preparing test releases to verify in-app auto-updating locally.
---

# AeroPulse Release Guide

A reference workflow for building, codesigning, appcast signing (Sparkle Ed25519), and publishing GitHub Releases for AeroPulse (`Flux-MacOSNetworkFanSpeed`).

## Core Principles

1. **Local-first Release Pipeline**: Releases are built and signed locally using `.sparkle_keys.env` and the bundled Sparkle tools (`.sparkle-tools/bin/generate_appcast`). Never rely on remote GitHub Actions for signing or building, as `.github/workflows/release.yml` has been removed to avoid Xcode version mismatch warnings.
2. **Two Release Modes**:
   - **Test-Update Mode (`--keep-local-version` / `-k`)**: Used when the user wants to test updating the app themselves. The remote GitHub Release and `appcast.xml` receive the new version (e.g. `1.3.2`), but the local `AeroPulse.xcodeproj/project.pbxproj` is reverted/kept at the previous version (e.g. `1.3.1`). This allows the local running app to detect the update, show update badges in MenuBar/Settings, and test downloading and replacing the app bundle.
   - **Standard Release Mode**: Both local `project.pbxproj` and remote GitHub Release are bumped to the new version.

## Preflight Checks

Before triggering a release, verify:

1. **Git Status**: Working directory in `/Users/tom/Documents/Flux-MacOSNetworkFanSpeed` should have all feature code committed.
   ```bash
   git -C /Users/tom/Documents/Flux-MacOSNetworkFanSpeed status -s
   ```
2. **Sparkle Private Key**:
   ```bash
   test -f /Users/tom/Documents/Flux-MacOSNetworkFanSpeed/.sparkle_keys.env && grep -q '^SPARKLE_PRIVATE_KEY=' /Users/tom/Documents/Flux-MacOSNetworkFanSpeed/.sparkle_keys.env
   ```
3. **GitHub CLI Auth**:
   ```bash
   gh auth status
   ```

## Execution

Navigate or run from the repo root `/Users/tom/Documents/Flux-MacOSNetworkFanSpeed`:

### Option A: Test-Update Mode (Local version remains unchanged)
Triggered when the user says:
- "发布新版本，先不要改本机上的版本号"
- "发版测试更新"
- "publish release for testing update"

Command:
```bash
# Auto-increments patch version and build number, keeping local version unchanged
./scripts/publish_release.sh --keep-local-version

# Or with explicit target version:
./scripts/publish_release.sh 1.3.2 15 --keep-local-version
```

### Option B: Standard Release Mode (Full Bump)
Triggered when the user says:
- "正式发布新版本"
- "发布 v1.3.2"
- "release new version"

Command:
```bash
# Auto-increments patch version and bumps local project
./scripts/publish_release.sh

# Or with explicit target version:
./scripts/publish_release.sh 1.3.2 15
```

## What the Script Does Automatically

1. Reads current version & build from `AeroPulse.xcodeproj/project.pbxproj`.
2. Computes or sets target version and build number.
3. Bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for compilation.
4. Performs `xcodebuild -configuration Release` clean build.
5. Injects localization bundles (`zh-Hans.lproj`, `en.lproj`) into `Contents/Resources`.
6. Ad-hoc codesigns the `.app` bundle.
7. Archives the bundle to `dist/AeroPulse.zip`.
8. Signs with Sparkle Ed25519 private key and appends entry to `appcast.xml`.
9. **If in Test-Update Mode**: restores local `project.pbxproj` to original version, commits only `appcast.xml` and `scripts/publish_release.sh` to `main`, and pushes.
10. **If in Standard Mode**: commits both `project.pbxproj` and `appcast.xml` to `main`, and pushes.
11. Pushes Git tag `v<VERSION>`.
12. Creates GitHub Release with `gh release create` and uploads `dist/AeroPulse.zip` and `appcast.xml`.

## Verification After Release

1. Verify GitHub Release:
   ```bash
   gh release view v<VERSION>
   ```
2. Verify remote `appcast.xml`:
   ```bash
   curl -s https://raw.githubusercontent.com/TomTang197/Flux-MacOSNetworkFanSpeed/main/appcast.xml | head -n 25
   ```
3. Check local project version:
   ```bash
   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" AeroPulse.xcodeproj/project.pbxproj
   ```
4. If in Test-Update Mode, instruct user:
   - Focus or restart the local AeroPulse app.
   - Wait 3 seconds for background auto-check or click **"Check for Updates…"** in Settings.
   - Verify the update banner / menu bar badge and click **"Update Now"**.
