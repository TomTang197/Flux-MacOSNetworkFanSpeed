#!/bin/zsh
set -euo pipefail

SERVICE_ID="com.bandan.me.MacOSNetworkFanSpeed.FanService"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/MacOSNetworkFanSpeed.xcodeproj"
PLIST_SOURCE="$ROOT_DIR/com.bandan.me.MacOSNetworkFanSpeed.FanService.plist"
INSTALL_HELPER="/Library/PrivilegedHelperTools/$SERVICE_ID"
INSTALL_PLIST="/Library/LaunchDaemons/$SERVICE_ID.plist"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0 [path/to/FanPrivilegedHelper]"
  exit 1
fi

if [[ ! -f "$PLIST_SOURCE" ]]; then
  echo "Missing launchd plist: $PLIST_SOURCE"
  exit 1
fi

HELPER_BIN="${1:-}"
if [[ -z "$HELPER_BIN" ]]; then
  echo "Resolving helper build output from xcodebuild..."
  BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme FanPrivilegedHelper -configuration Debug -showBuildSettings)"
  BUILT_PRODUCTS_DIR="$(printf "%s\n" "$BUILD_SETTINGS" | awk -F' = ' '/BUILT_PRODUCTS_DIR/ {print $2; exit}')"
  EXECUTABLE_PATH="$(printf "%s\n" "$BUILD_SETTINGS" | awk -F' = ' '/EXECUTABLE_PATH/ {print $2; exit}')"
  if [[ -n "$BUILT_PRODUCTS_DIR" && -n "$EXECUTABLE_PATH" ]]; then
    HELPER_BIN="$BUILT_PRODUCTS_DIR/$EXECUTABLE_PATH"
  fi
fi

if [[ -z "$HELPER_BIN" || ! -f "$HELPER_BIN" ]]; then
  echo "Helper executable not found."
  echo "Pass it explicitly: sudo $0 /absolute/path/to/FanPrivilegedHelper"
  exit 1
fi

echo "Installing helper:"
echo "  Source: $HELPER_BIN"
echo "  Dest:   $INSTALL_HELPER"
install -d -m 755 /Library/PrivilegedHelperTools
install -m 755 "$HELPER_BIN" "$INSTALL_HELPER"
chown root:wheel "$INSTALL_HELPER"

echo "Installing launchd plist:"
echo "  Source: $PLIST_SOURCE"
echo "  Dest:   $INSTALL_PLIST"
install -d -m 755 /Library/LaunchDaemons
install -m 644 "$PLIST_SOURCE" "$INSTALL_PLIST"
chown root:wheel "$INSTALL_PLIST"

echo "Reloading launchd service..."
launchctl bootout system/"$SERVICE_ID" >/dev/null 2>&1 || true
launchctl bootstrap system "$INSTALL_PLIST"
launchctl enable system/"$SERVICE_ID"
launchctl kickstart -k system/"$SERVICE_ID"

echo
echo "Helper install complete."
echo "Check status with:"
echo "  launchctl print system/$SERVICE_ID | head -n 40"
