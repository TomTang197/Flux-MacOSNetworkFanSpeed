#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/setup_notary_profile.sh \
    --profile <profile_name> \
    --apple-id <apple_id_email> \
    --team-id <team_id> \
    [--password <app_specific_password>]

Notes:
- If --password is omitted, the script prompts securely.
- The profile is stored in your login keychain for xcrun notarytool.
USAGE
}

PROFILE_NAME=""
APPLE_ID=""
TEAM_ID=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --apple-id)
      APPLE_ID="$2"
      shift 2
      ;;
    --team-id)
      TEAM_ID="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
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

if [[ -z "$PROFILE_NAME" || -z "$APPLE_ID" || -z "$TEAM_ID" ]]; then
  usage
  exit 1
fi

if [[ -z "$PASSWORD" ]]; then
  read -r -s -p "App-specific password: " PASSWORD
  echo
fi

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$PASSWORD"

echo "Stored notary profile: $PROFILE_NAME"
