#!/usr/bin/env bash
# =============================================================================
# debug-status.sh
#
# On-demand diagnostic snapshot for the BlueBubbles + Beeper + Tailscale stack.
# Run at any time to see the current state of all components.
#
# Usage:
#   bash debug-status.sh              # summary
#   bash debug-status.sh --log N      # also print last N lines of bridge log (default 50)
#   bash debug-status.sh --errors     # print only ERR/WRN lines from bridge log
# =============================================================================

set -uo pipefail

# ── Constants (must match setup-tailscale-serve.sh) ───────────────────────────
CONFIG_DIR="$HOME/.config/bb-beeper"
CONFIG_FILE="$CONFIG_DIR/config.env"
BRIDGE_RUNNER="$CONFIG_DIR/run-bridge.sh"
LOG_FILE="$HOME/Library/Logs/bb-beeper-bridge.log"
LAUNCH_LABEL="com.user.bb-beeper-bridge"
LAUNCH_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_LABEL}.plist"
BBCTL_BIN="$HOME/.local/bin/bbctl"
BB_PORT=1234

# ── Colours ───────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
BOLD='\033[1m'; N='\033[0m'

ok()   { printf "${G}[✓]${N} %s\n" "$*"; }
warn() { printf "${Y}[!]${N} %s\n" "$*"; }
err()  { printf "${R}[✗]${N} %s\n" "$*"; }
info() { printf "${B}[→]${N} %s\n" "$*"; }
sep()  { printf "${BOLD}${B}────────────────────────────────────────${N}\n"; }

# ── Args ──────────────────────────────────────────────────────────────────────
SHOW_LOG=false
LOG_LINES=50
ERRORS_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)    SHOW_LOG=true; [[ "${2:-}" =~ ^[0-9]+$ ]] && { LOG_LINES="$2"; shift; }; shift ;;
    --errors) ERRORS_ONLY=true; SHOW_LOG=true; shift ;;
    *)        shift ;;
  esac
done

# ── Load config ───────────────────────────────────────────────────────────────
BB_LOCAL_URL="http://localhost:${BB_PORT}"
BB_PASSWORD=""
TAILSCALE_URL=""

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

echo
printf "${BOLD}${B}  BlueBubbles + Beeper + Tailscale — Debug Status${N}\n"
printf "  $(date '+%Y-%m-%d %H:%M:%S %Z')\n"

# =============================================================================
sep
printf "${BOLD}1. LaunchAgent${N}\n"
# =============================================================================

if [[ -f "$LAUNCH_PLIST" ]]; then
  ok "Plist exists: $LAUNCH_PLIST"
else
  err "Plist missing: $LAUNCH_PLIST"
fi

launchctl_entry="$(launchctl list 2>/dev/null | grep "$LAUNCH_LABEL" || true)"
if [[ -n "$launchctl_entry" ]]; then
  pid="$(echo "$launchctl_entry" | awk '{print $1}')"
  exit_code="$(echo "$launchctl_entry" | awk '{print $2}')"
  if [[ "$pid" == "-" ]]; then
    if [[ "$exit_code" == "0" ]]; then
      warn "LaunchAgent registered but not running (last exit: 0)"
    else
      err "LaunchAgent registered but not running (last exit code: $exit_code)"
    fi
  else
    ok "LaunchAgent running (PID: $pid)"
  fi
else
  err "LaunchAgent not registered with launchd"
fi

# =============================================================================
sep
printf "${BOLD}2. bbctl / Bridge process${N}\n"
# =============================================================================

if [[ -x "$BBCTL_BIN" ]]; then
  ok "bbctl binary: $BBCTL_BIN ($(${BBCTL_BIN} version 2>/dev/null | head -1 || echo 'version unknown'))"
else
  err "bbctl binary not found or not executable: $BBCTL_BIN"
fi

bbctl_pids="$(pgrep -f 'bbctl run' 2>/dev/null | tr '\n' ' ' || true)"
if [[ -n "$bbctl_pids" ]]; then
  ok "bbctl run process(es): PID $bbctl_pids"
else
  err "No 'bbctl run' process found"
fi

mautrix_pids="$(pgrep -f 'mautrix-imessage' 2>/dev/null | tr '\n' ' ' || true)"
if [[ -n "$mautrix_pids" ]]; then
  ok "mautrix-imessage process(es): PID $mautrix_pids"
else
  warn "No mautrix-imessage process found"
fi

# =============================================================================
sep
printf "${BOLD}3. Beeper login (bbctl whoami)${N}\n"
# =============================================================================

if [[ -x "$BBCTL_BIN" ]]; then
  whoami_out="$("$BBCTL_BIN" whoami 2>&1 || true)"
  if echo "$whoami_out" | grep -qi "you're not logged in"; then
    err "bbctl not logged in — run: $BBCTL_BIN login"
    echo "$whoami_out" | sed 's/^/    /'
  elif [[ -z "$whoami_out" ]]; then
    warn "bbctl whoami returned no output"
  else
    ok "bbctl whoami:"
    echo "$whoami_out" | sed 's/^/    /'
  fi
fi

# =============================================================================
sep
printf "${BOLD}4. BlueBubbles Server${N}\n"
# =============================================================================

if nc -z localhost "$BB_PORT" 2>/dev/null; then
  ok "Port $BB_PORT: open"
else
  err "Port $BB_PORT: not reachable — is BlueBubbles Server running?"
fi

# Try the health/info endpoint
if [[ -n "$BB_PASSWORD" ]]; then
  http_code="$(curl -sf --max-time 5 \
    "${BB_LOCAL_URL}/api/v1/server/info?password=${BB_PASSWORD}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "ERR")"
  if [[ "$http_code" == "200" ]]; then
    ok "BlueBubbles API /api/v1/server/info → HTTP $http_code"
  elif [[ "$http_code" == "ERR" ]]; then
    err "BlueBubbles API request failed (curl error)"
  else
    warn "BlueBubbles API /api/v1/server/info → HTTP $http_code (check password in config)"
  fi
else
  warn "No BB_PASSWORD in config — skipping API health check"
fi

# =============================================================================
sep
printf "${BOLD}5. Tailscale${N}\n"
# =============================================================================

if command -v tailscale &>/dev/null; then
  ts_status="$(tailscale status 2>&1 | head -3)"
  ok "Tailscale CLI found: $(tailscale version | head -1)"
  echo "$ts_status" | sed 's/^/    /'

  echo
  info "Tailscale serve status:"
  tailscale serve status 2>&1 | sed 's/^/    /' || warn "tailscale serve status failed"

  ts_url="$(python3 - 2>/dev/null <<'PYEOF'
import subprocess, json, sys
try:
    raw = subprocess.check_output(["tailscale", "status", "--json"])
    d = json.loads(raw)
    dns = d["Self"]["DNSName"].rstrip(".")
    print(f"https://{dns}")
except Exception:
    pass
PYEOF
  )"
  if [[ -n "$ts_url" ]]; then
    ok "MagicDNS URL: $ts_url"
    if [[ "$TAILSCALE_URL" != "$ts_url" ]]; then
      info "Config TAILSCALE_URL ($TAILSCALE_URL) differs from current MagicDNS URL ($ts_url)"
      info "Bridge uses localhost — this only matters for remote clients (phone/tablet)."
      info "Run setup-tailscale-serve.sh to update if needed."
    fi
  fi
else
  err "tailscale CLI not found in PATH"
fi

# =============================================================================
sep
printf "${BOLD}6. Config file${N}\n"
# =============================================================================

if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config: $CONFIG_FILE"
  # Print config but mask the password
  while IFS= read -r line; do
    if [[ "$line" =~ ^BB_PASSWORD ]]; then
      echo "    BB_PASSWORD=<redacted>"
    else
      echo "    $line"
    fi
  done < "$CONFIG_FILE"
else
  err "Config file missing: $CONFIG_FILE"
fi

# =============================================================================
sep
printf "${BOLD}7. Log file${N}\n"
# =============================================================================

if [[ -f "$LOG_FILE" ]]; then
  log_size="$(du -sh "$LOG_FILE" 2>/dev/null | cut -f1)"
  log_modified="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOG_FILE" 2>/dev/null || date -r "$LOG_FILE" 2>/dev/null || echo 'unknown')"
  ok "Log: $LOG_FILE (${log_size}, last modified: ${log_modified})"

  # Always show last error/warning lines (log uses ANSI codes, match on text content)
  err_count="$(grep -c ' ERR ' "$LOG_FILE" 2>/dev/null || true)"
  err_count="${err_count:-0}"
  if [[ "$err_count" -gt 0 ]]; then
    warn "Found ${err_count} ERR lines in log. Most recent:"
    grep ' ERR ' "$LOG_FILE" | tail -10 | sed 's/^/    /'
  else
    ok "No ERR lines in log"
  fi

  if $SHOW_LOG; then
    echo
    if $ERRORS_ONLY; then
      info "All ERR lines from log:"
      grep ' ERR ' "$LOG_FILE" | sed 's/^/    /' || echo "    (none)"
    else
      info "Last ${LOG_LINES} lines of log:"
      tail -"${LOG_LINES}" "$LOG_FILE" | sed 's/^/    /'
    fi
  else
    info "Tip: run with --log to print recent log lines, or --errors for errors only"
  fi
else
  warn "Log file not found: $LOG_FILE (bridge may not have started yet)"
fi

# =============================================================================
sep
printf "${BOLD}8. Quick fixes${N}\n"
# =============================================================================

echo "  Restart bridge:    launchctl unload $LAUNCH_PLIST && launchctl load $LAUNCH_PLIST"
echo "  Tail logs:         tail -f $LOG_FILE"
echo "  Errors only:       bash debug-status.sh --errors"
echo "  Re-login Beeper:   $BBCTL_BIN login"
echo "  Reconfigure:       bash setup-tailscale-serve.sh"
echo "  Force reset:       bash setup-tailscale-serve.sh --reset"
echo
