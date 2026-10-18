#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PBXPROJ="$ROOT_DIR/AeroPulse.xcodeproj/project.pbxproj"
CURRENT_VERSION=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' "$PBXPROJ" | head -n1)
CURRENT_BUILD=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/p' "$PBXPROJ" | head -n1)

KEEP_LOCAL_VERSION=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --keep-local-version|--test-update|-k)
      KEEP_LOCAL_VERSION=true
      ;;
    --help|-h)
      echo "Usage: $0 [version] [build_number] [--keep-local-version]"
      echo ""
      echo "Options:"
      echo "  --keep-local-version, -k    Publish release on GitHub but revert local project version"
      echo "                              to allow testing the in-app update process locally."
      echo "  version                     Optional. Defaults to next patch version."
      echo "  build_number                Optional. Defaults to current build + 1."
      exit 0
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done

if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
  VERSION="${POSITIONAL_ARGS[0]}"
else
  # Auto-compute next patch version
  IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
  patch=$((patch + 1))
  VERSION="${major}.${minor}.${patch}"
fi

if [[ ${#POSITIONAL_ARGS[@]} -ge 2 ]]; then
  BUILD="${POSITIONAL_ARGS[1]}"
else
  BUILD=$((CURRENT_BUILD + 1))
fi

echo "=========================================================="
echo "Publishing AeroPulse Release: v${VERSION} (Build ${BUILD})"
if [[ "$KEEP_LOCAL_VERSION" == true ]]; then
  echo "Mode: Test Update Mode (Local version will stay at ${CURRENT_VERSION} / ${CURRENT_BUILD})"
else
  echo "Mode: Standard Release (Local version will be bumped to ${VERSION} / ${BUILD})"
fi
echo "=========================================================="

# Backup current project.pbxproj content in memory
ORIGINAL_PBXPROJ=$(cat "$PBXPROJ")

# 1. Bump version for release build
./scripts/bump_version.sh "$VERSION" "$BUILD"

# 2. Check keys
if [[ ! -f ".sparkle_keys.env" ]]; then
  echo "Error: .sparkle_keys.env not found. Run python3 scripts/generate_sparkle_keys.py first." >&2
  # Restore project file if aborting
  printf "%s\n" "$ORIGINAL_PBXPROJ" > "$PBXPROJ"
  exit 1
fi

PRIVATE_KEY=$(grep '^SPARKLE_PRIVATE_KEY=' .sparkle_keys.env | cut -d'=' -f2-)
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "Error: SPARKLE_PRIVATE_KEY not found in .sparkle_keys.env" >&2
  printf "%s\n" "$ORIGINAL_PBXPROJ" > "$PBXPROJ"
  exit 1
fi

# 3. Clean and build Release
echo "==> Building AeroPulse Release..."
rm -rf build dist
xcodebuild -project AeroPulse.xcodeproj \
           -scheme AeroPulse \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGNING_ALLOWED=NO \
           build

APP_PATH="build/Build/Products/Release/AeroPulse.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: Built app not found at $APP_PATH" >&2
  printf "%s\n" "$ORIGINAL_PBXPROJ" > "$PBXPROJ"
  exit 1
fi

# Ensure localizations are in Contents/Resources
mkdir -p "$APP_PATH/Contents/Resources/zh-Hans.lproj"
mkdir -p "$APP_PATH/Contents/Resources/en.lproj"
cp -R AeroPulse/Resources/zh-Hans.lproj/* "$APP_PATH/Contents/Resources/zh-Hans.lproj/" 2>/dev/null || true
cp -R AeroPulse/Resources/en.lproj/* "$APP_PATH/Contents/Resources/en.lproj/" 2>/dev/null || true

# 4. Ad-hoc codesign
echo "==> Signing application bundle..."
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

# 5. Archive to dist/AeroPulse.zip
mkdir -p dist
ditto -c -k --keepParent "$APP_PATH" dist/AeroPulse.zip

# 6. Prepare Sparkle tools
TOOLS_DIR="$ROOT_DIR/.sparkle-tools"
if [[ ! -f "$TOOLS_DIR/bin/generate_appcast" ]]; then
  echo "==> Downloading Sparkle tools..."
  mkdir -p "$TOOLS_DIR"
  curl -sL -o /tmp/sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz"
  tar -xf /tmp/sparkle.tar.xz -C "$TOOLS_DIR"
  rm -f /tmp/sparkle.tar.xz
fi

# 7. Generate signed appcast
echo "==> Generating signed appcast..."
cp appcast.xml dist/ || true
KEY_FILE=$(mktemp)
printf "%s" "$PRIVATE_KEY" > "$KEY_FILE"
rm -rf "$HOME/Library/Caches/Sparkle_generate_appcast"
"$TOOLS_DIR/bin/generate_appcast" \
  --download-url-prefix "https://github.com/TomTang197/Flux-MacOSNetworkFanSpeed/releases/download/v${VERSION}/" \
  --ed-key-file "$KEY_FILE" \
  dist/
rm -f "$KEY_FILE"
cp dist/appcast.xml ./appcast.xml

# 8. Handle local version restoration & Git commit
if [[ "$KEEP_LOCAL_VERSION" == true ]]; then
  echo "==> Restoring local project.pbxproj to ${CURRENT_VERSION} (${CURRENT_BUILD}) for test-update mode..."
  printf "%s\n" "$ORIGINAL_PBXPROJ" > "$PBXPROJ"
  git add appcast.xml scripts/publish_release.sh
  git diff --staged --quiet || git commit -m "chore(release): release v${VERSION} appcast"
  git push origin main
else
  git add AeroPulse.xcodeproj/project.pbxproj appcast.xml scripts/publish_release.sh
  git diff --staged --quiet || git commit -m "chore(release): release v${VERSION}"
  git push origin main
fi

# 9. Tag and push
TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -d "$TAG"
  git push origin --delete "$TAG" 2>/dev/null || true
fi
git tag "$TAG"
git push origin "$TAG"

# 10. Create GitHub Release
echo "==> Creating GitHub Release..."
gh release create "$TAG" dist/AeroPulse.zip appcast.xml \
  --title "v${VERSION}" \
  --generate-notes

echo "==> Release v${VERSION} published successfully!"
if [[ "$KEEP_LOCAL_VERSION" == true ]]; then
  echo "==> [Notice] Local project remained at v${CURRENT_VERSION} (${CURRENT_BUILD}). You can now test in-app updating!"
fi
