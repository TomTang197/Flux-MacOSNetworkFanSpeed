#!/bin/zsh
set -euo pipefail

SERVICE_ID="com.bandan.me.MacOSNetworkFanSpeed.FanService"
INSTALL_HELPER="/Library/PrivilegedHelperTools/$SERVICE_ID"
INSTALL_PLIST="/Library/LaunchDaemons/$SERVICE_ID.plist"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

echo "Stopping launchd service..."
launchctl bootout system/"$SERVICE_ID" >/dev/null 2>&1 || true
launchctl disable system/"$SERVICE_ID" >/dev/null 2>&1 || true

echo "Removing files..."
rm -f "$INSTALL_PLIST"
rm -f "$INSTALL_HELPER"

echo "Helper removed."
