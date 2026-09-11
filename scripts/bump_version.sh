#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT_DIR/AeroPulse.xcodeproj/project.pbxproj"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build_number]"
  echo "Example: $0 1.1.0 2"
  exit 1
fi

NEW_VERSION="$1"
NEW_BUILD="${2:-}"

# Extract current version
CURRENT_VERSION=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/p' "$PBXPROJ" | head -n1)
CURRENT_BUILD=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/p' "$PBXPROJ" | head -n1)

if [[ -z "$NEW_BUILD" ]]; then
  if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    NEW_BUILD=$((CURRENT_BUILD + 1))
  else
    NEW_BUILD=1
  fi
fi

echo "Bumping version from ${CURRENT_VERSION} (${CURRENT_BUILD}) to ${NEW_VERSION} (${NEW_BUILD})..."

# Replace MARKETING_VERSION and CURRENT_PROJECT_VERSION
sed -i '' -E "s/(MARKETING_VERSION = )[^;]+;/\1${NEW_VERSION};/g" "$PBXPROJ"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )[^;]+;/\1${NEW_BUILD};/g" "$PBXPROJ"

echo "Updated $PBXPROJ:"
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" "$PBXPROJ"
