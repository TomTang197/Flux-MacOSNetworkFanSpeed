#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AeroPulse.xcodeproj"
SCHEME="AeroPulse"
CONFIGURATION="Release"
OUTPUT_DIR="$ROOT_DIR/dist/release"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE=1
CLEAN=1

usage() {
  cat <<'USAGE'
Usage:
  scripts/release_external.sh [options]

Options:
  --notary-profile <name>   notarytool keychain profile name
  --output <dir>            output directory (default: dist/release)
  --no-notarize             skip notarization/stapling
  --no-clean                keep existing output directory contents
  -h, --help                show help

Environment variables:
  TEAM_ID                   override team id used for export options
  NOTARY_PROFILE            same as --notary-profile

Requirements for external distribution:
- Developer ID Application certificate in login keychain
- xcodebuild, xcrun, hdiutil available
- For notarization: notary profile created via scripts/setup_notary_profile.sh
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notary-profile)
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --no-notarize)
      NOTARIZE=0
      shift
      ;;
    --no-clean)
      CLEAN=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found: $PROJECT_PATH" >&2
  exit 1
fi

for cmd in xcodebuild xcrun hdiutil ditto security; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  echo "No 'Developer ID Application' identity found in keychain." >&2
  echo "Install your Developer ID certificate first." >&2
  exit 1
fi

DEFAULT_TEAM_ID="$(sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]*\);.*/\1/p' "$PROJECT_PATH/project.pbxproj" | head -n1)"
TEAM_ID="${TEAM_ID:-$DEFAULT_TEAM_ID}"

if [[ -z "$TEAM_ID" ]]; then
  echo "Unable to detect TEAM_ID. Set TEAM_ID environment variable and retry." >&2
  exit 1
fi

if [[ "$NOTARIZE" -eq 1 && -z "$NOTARY_PROFILE" ]]; then
  echo "Notarization requested but no notary profile provided." >&2
  echo "Pass --notary-profile <name> or set NOTARY_PROFILE." >&2
  exit 1
fi

if [[ "$CLEAN" -eq 1 ]]; then
  rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$OUTPUT_DIR/export"
STAGING_DIR="$OUTPUT_DIR/dmg-root"
DMG_PATH="$OUTPUT_DIR/${SCHEME}-macOS.dmg"
ZIP_PATH="$OUTPUT_DIR/${SCHEME}-macOS.zip"
LOG_PATH="$OUTPUT_DIR/notary-log.json"
EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/ExportOptions.plist"

cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>stripSwiftSymbols</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Archiving $SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "==> Exporting signed app"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_DIR/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Exported app not found: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

rm -f "$DMG_PATH" "$ZIP_PATH"

echo "==> Building DMG"
hdiutil create \
  -volname "$SCHEME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "==> Submitting DMG for notarization"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json > "$LOG_PATH"

  echo "==> Stapling app + DMG"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler staple "$DMG_PATH"

  echo "==> Gatekeeper validation"
  spctl --assess --type execute --verbose=4 "$APP_PATH"
  spctl --assess --type open --verbose=4 "$DMG_PATH"
else
  echo "==> Notarization skipped"
fi

echo "==> Building ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Release artifacts:"
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
echo "  ZIP: $ZIP_PATH"
if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "  Notary log: $LOG_PATH"
fi
