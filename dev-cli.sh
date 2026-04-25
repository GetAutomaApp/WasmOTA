#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_LOG="$ROOT_DIR/.ota-test-server.log"
SERVER_PID_FILE="$ROOT_DIR/.ota-test-server.pid"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_MAGENTA=$'\033[35m'
else
  C_RESET=""
  C_CYAN=""
  C_GREEN=""
  C_YELLOW=""
  C_MAGENTA=""
fi

log_section() {
  local label="$1"
  local color="$2"
  printf "%b%s%b\n" "$color" ">> $label" "$C_RESET"
}

prefix_stream() {
  local label="$1"
  local color="$2"
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf "  %b[%s]%b %s\n" "$color" "$label" "$C_RESET" "$line"
  done
}

run_logged() {
  local label="$1"
  local color="$2"
  shift 2
  log_section "$label" "$color"
  set +e
  "$@" 2>&1 | prefix_stream "$label" "$color"
  local status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

start_server() {
  if [[ -f "$SERVER_PID_FILE" ]]; then
    local pid
    pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return
    fi
  fi

  : > "$SERVER_LOG"
  (cd "$ROOT_DIR" && python3 ota-test-server.py >>"$SERVER_LOG" 2>&1 & echo $! >"$SERVER_PID_FILE")
  sleep 0.2
}

stop_server() {
  if [[ -f "$SERVER_PID_FILE" ]]; then
    local pid
    pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" || true
    fi
    rm -f "$SERVER_PID_FILE"
  fi
}

ensure_server() {
  start_server
}

build_wasm() {
  run_logged "build:wasm" "$C_CYAN" npm run build:wasm
}

build_example() {
  run_logged "build:example" "$C_CYAN" npm run build:example
}

run_example() {
  run_logged "run:example" "$C_GREEN" npm run run:example:swift
}

run_wasm() {
  run_logged "run:wasm" "$C_GREEN" npm run run:wasm
}

show_logs() {
  if [[ ! -f "$SERVER_LOG" ]]; then
    echo "No server log yet."
    return
  fi
  log_section "ota-test-server logs" "$C_MAGENTA"
  tail -n 80 "$SERVER_LOG" | prefix_stream "ota-test-server" "$C_MAGENTA"
}

status() {
  if [[ -f "$SERVER_PID_FILE" ]] && kill -0 "$(cat "$SERVER_PID_FILE" 2>/dev/null || true)" 2>/dev/null; then
    echo "ota-test-server: running (pid $(cat "$SERVER_PID_FILE"))"
  else
    echo "ota-test-server: stopped"
  fi
}

trap stop_server EXIT
ensure_server

print_menu() {
  cat <<'EOF'
Commands:
  b  build wasm only
  e  build example
  r  run example without rebuilding
  w  run wasm test without rebuilding
  o  show ota-test-server logs
  s  server status
  q  quit
EOF
}

while true; do
  print_menu
  printf '> '
  stty -echo -icanon time 0 min 1
  IFS= read -r -n 1 cmd || {
    stty echo icanon
    exit 0
  }
  stty echo icanon
  printf '\n'
  case "$cmd" in
    b) build_wasm ;;
    e) build_example ;;
    r) run_example ;;
    w) run_wasm ;;
    o) show_logs ;;
    s) status ;;
    q) exit 0 ;;
    "") ;;
    *) echo "Unknown command: $cmd" ;;
  esac
  printf '\n'
done
