#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build_number]"
  echo "Example: $0 1.1.0 2"
  exit 1
fi

VERSION="$1"
BUILD="${2:-}"

# 1. Bump version
./scripts/bump_version.sh "$VERSION" $BUILD

# 2. Check keys
if [[ ! -f ".sparkle_keys.env" ]]; then
  echo "Error: .sparkle_keys.env not found. Run python3 scripts/generate_sparkle_keys.py first." >&2
  exit 1
fi

PRIVATE_KEY=$(grep '^SPARKLE_PRIVATE_KEY=' .sparkle_keys.env | cut -d'=' -f2-)
if [[ -z "$PRIVATE_KEY" ]]; then
  echo "Error: SPARKLE_PRIVATE_KEY not found in .sparkle_keys.env" >&2
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
  exit 1
fi

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

# 8. Commit, tag and push
echo "==> Committing and pushing release..."
git add AeroPulse.xcodeproj/project.pbxproj appcast.xml scripts/publish_release.sh
git diff --staged --quiet || git commit -m "chore(release): release v${VERSION}"
git push origin main

TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -d "$TAG"
  git push origin --delete "$TAG" 2>/dev/null || true
fi
git tag "$TAG"
git push origin "$TAG"

# 9. Create GitHub Release
echo "==> Creating GitHub Release..."
gh release create "$TAG" dist/AeroPulse.zip appcast.xml \
  --title "v${VERSION}" \
  --generate-notes

echo "==> Release v${VERSION} published successfully!"
