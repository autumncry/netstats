#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
if [[ $# -gt 0 ]]; then shift; fi
if [[ "${1:-}" == "--" ]]; then shift; fi

case "$MODE" in
  run|--verify|--debug|--logs|--telemetry) ;;
  *) echo "Usage: $0 [run|--verify|--debug|--logs|--telemetry] [-- app-arguments]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/NetStats.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/NetStats"

pkill -x NetStats >/dev/null 2>&1 || true
bash "$ROOT_DIR/scripts/package_app.sh" "${NETSTATS_BUILD_CONFIGURATION:-debug}"
# This signature is for the locally built development bundle, not distribution.
/usr/bin/codesign --force --sign - "$APP_BUNDLE"

open_app() {
  if [[ $# -gt 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  run) open_app "$@" ;;
  --verify)
    open_app "$@"
    sleep 1
    pgrep -x NetStats >/dev/null
    echo "NetStats is running from $APP_BUNDLE"
    ;;
  --debug) lldb -- "$APP_BINARY" "$@" ;;
  --logs)
    open_app "$@"
    /usr/bin/log stream --info --style compact --predicate 'process == "NetStats"'
    ;;
  --telemetry)
    open_app "$@"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.ronnycao.netstats"'
    ;;
esac
