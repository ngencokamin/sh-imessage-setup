#!/usr/bin/env bash
# =============================================================================
# setup-bb-beeper.sh
#
# Reproducible setup for:
#   BlueBubbles Server  →  Tailscale Serve (HTTPS)  →  bbctl sh-imessage bridge
#   (sends messages through Beeper)
#
# Reference: https://github.com/ngencokamin/sh-imessage-setup
#
# Prerequisites (already installed):
#   • BlueBubbles Server running on this Mac
#   • Tailscale connected (standalone install recommended)
#   • Homebrew
#   • Beeper account
#
# Usage:
#   bash setup-bb-beeper.sh            # first-time setup or update
#   bash setup-bb-beeper.sh --reset    # force re-prompt of all config
# =============================================================================

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly BBCTL_BIN="$HOME/.local/bin/bbctl"
readonly CONFIG_DIR="$HOME/.config/bb-beeper"
readonly CONFIG_FILE="$CONFIG_DIR/config.env"
readonly BRIDGE_RUNNER="$CONFIG_DIR/run-bridge.sh"
readonly LOG_FILE="$HOME/Library/Logs/bb-beeper-bridge.log"
readonly LAUNCH_LABEL="com.user.bb-beeper-bridge"
readonly LAUNCH_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_LABEL}.plist"
readonly BB_PORT=1234
readonly ARCH="$(uname -m)"

# ── Colours ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
BOLD='\033[1m'; N='\033[0m'

info()  { printf "${B}[→]${N} %s\n" "$*"; }
ok()    { printf "${G}[✓]${N} %s\n" "$*"; }
warn()  { printf "${Y}[!]${N} %s\n" "$*"; }
die()   { printf "${R}[✗]${N} %s\n" "$*" >&2; exit 1; }
sep()   { printf "${BOLD}${B}────────────────────────────────────────${N}\n"; }

# ── Globals set during run ─────────────────────────────────────────────────────
TAILSCALE_URL=""
BB_PASSWORD=""
RESET=false

# ── Parse args ─────────────────────────────────────────────────────────────────
for arg in "$@"; do
  [[ "$arg" == "--reset" ]] && RESET=true
done

# =============================================================================
# STEP 1 — Prerequisites
# =============================================================================
check_prereqs() {
  sep
  info "Checking prerequisites..."

  # Must be macOS
  [[ "$(uname -s)" == "Darwin" ]] || die "This script requires macOS."
  ok "macOS detected: $(sw_vers -productVersion)"

  # Homebrew
  command -v brew &>/dev/null || die "Homebrew not found. Install from https://brew.sh"
  ok "Homebrew: $(brew --version | head -1)"

  # Tailscale CLI in PATH
  if ! command -v tailscale &>/dev/null; then
    # Try common locations for standalone install
    for ts_path in /usr/local/bin/tailscale /opt/homebrew/bin/tailscale \
                   /Applications/Tailscale.app/Contents/MacOS/tailscale; do
      if [[ -x "$ts_path" ]]; then
        export PATH="$(dirname "$ts_path"):$PATH"
        break
      fi
    done
  fi
  command -v tailscale &>/dev/null || die "tailscale CLI not found. Install via: brew install tailscale"
  ok "Tailscale CLI: $(tailscale version | head -1)"

  # Tailscale connected
  if ! tailscale status &>/dev/null; then
    die "Tailscale is not connected. Run 'tailscale up' first."
  fi
  ok "Tailscale: connected"

  # BlueBubbles running on expected port
  if ! nc -z localhost "$BB_PORT" 2>/dev/null; then
    die "Cannot reach BlueBubbles Server on localhost:${BB_PORT}.\nPlease open BlueBubbles Server and ensure it is running."
  fi
  ok "BlueBubbles Server: listening on port ${BB_PORT}"
}

# =============================================================================
# STEP 2 — Install bbctl
# =============================================================================
install_bbctl() {
  sep
  info "Checking bbctl (Beeper Bridge Manager)..."

  if [[ -x "$BBCTL_BIN" ]] && ! $RESET; then
    ok "bbctl already installed: $("$BBCTL_BIN" version 2>/dev/null | head -1 || echo 'unknown version')"
    return
  fi

  info "Installing latest bbctl binary..."
  mkdir -p "$(dirname "$BBCTL_BIN")"

  local download_url
  if [[ "$ARCH" == "arm64" ]]; then
    download_url="https://github.com/beeper/bridge-manager/releases/latest/download/bbctl-darwin-arm64"
  else
    download_url="https://github.com/beeper/bridge-manager/releases/latest/download/bbctl-darwin"
  fi

  curl -fsSL "$download_url" -o "$BBCTL_BIN" \
    || die "Failed to download bbctl. Check your internet connection."
  chmod +x "$BBCTL_BIN"
  ok "bbctl installed → $BBCTL_BIN"

  # Ensure ~/.local/bin is on PATH for this session
  export PATH="$HOME/.local/bin:$PATH"

  # Remind user to persist this
  if ! grep -q 'local/bin' "${HOME}/.zshrc" 2>/dev/null && \
     ! grep -q 'local/bin' "${HOME}/.bashrc" 2>/dev/null; then
    warn "Add ~/.local/bin to your shell PATH:"
    warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
  fi
}

# =============================================================================
# STEP 3 — Login to Beeper via bbctl
# =============================================================================
login_bbctl() {
  sep
  info "Verifying Beeper login..."

  if "$BBCTL_BIN" whoami &>/dev/null; then
    local user
    user="$("$BBCTL_BIN" whoami 2>/dev/null | head -1)"
    ok "Logged in to Beeper as: ${user}"
    return
  fi

  info "Opening Beeper login (browser)..."
  "$BBCTL_BIN" login \
    || die "Beeper login failed. Ensure you have a Beeper account and retry."
  ok "Logged in to Beeper"
}

# =============================================================================
# STEP 4 — Configure Tailscale Serve
# =============================================================================
setup_tailscale_serve() {
  sep
  info "Configuring Tailscale Serve (HTTPS → localhost:${BB_PORT})..."

  # Tear down any existing serve on this port to avoid conflicts
  tailscale serve --https=443 off 2>/dev/null || true

  # Set up HTTPS serve: external HTTPS:443 → local HTTP:BB_PORT
  # Try without sudo first (standalone install), then with sudo (system install)
  if ! tailscale serve --bg "${BB_PORT}" 2>/dev/null; then
    if ! sudo tailscale serve --bg "${BB_PORT}" 2>/dev/null; then
      # Older tailscale syntax fallback
      tailscale serve --bg "http://localhost:${BB_PORT}" 2>/dev/null \
        || sudo tailscale serve --bg "http://localhost:${BB_PORT}" 2>/dev/null \
        || die "Could not configure Tailscale Serve. Ensure Tailscale is up to date."
    fi
  fi

  sleep 2  # give serve a moment to initialise

  # Derive the HTTPS URL from tailscale status
  TAILSCALE_URL="$(_get_tailscale_url)"
  ok "Tailscale Serve URL: ${TAILSCALE_URL}"
}

_get_tailscale_url() {
  # Parse the machine's MagicDNS name from tailscale status JSON
  # Strips trailing dot, produces: https://hostname.tailnet.ts.net
  python3 - <<'PYEOF'
import subprocess, json, sys
try:
    raw = subprocess.check_output(["tailscale", "status", "--json"])
    d = json.loads(raw)
    dns = d["Self"]["DNSName"].rstrip(".")
    print(f"https://{dns}")
except Exception as e:
    print("", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# =============================================================================
# STEP 5 — Collect BlueBubbles password
# =============================================================================
get_bb_password() {
  sep
  info "BlueBubbles Server password..."

  # Load from existing config unless --reset
  if [[ -f "$CONFIG_FILE" ]] && ! $RESET; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    if [[ -n "${BB_PASSWORD:-}" ]]; then
      ok "Using saved password (run with --reset to change)"
      return
    fi
  fi

  printf "${BOLD}Enter your BlueBubbles Server password:${N} "
  read -rs BB_PASSWORD
  echo
  [[ -n "$BB_PASSWORD" ]] || die "Password cannot be empty."
  ok "Password accepted"
}

# =============================================================================
# STEP 6 — Save config
# =============================================================================
save_config() {
  sep
  info "Saving configuration..."

  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
# ── bb-beeper bridge config ──────────────────────────────
# Generated by setup-bb-beeper.sh v${SCRIPT_VERSION} on $(date)
# Re-run setup-bb-beeper.sh to update.

TAILSCALE_URL="${TAILSCALE_URL}"
BB_PASSWORD="${BB_PASSWORD}"
BB_PORT="${BB_PORT}"
BBCTL_BIN="${BBCTL_BIN}"
EOF
  chmod 600 "$CONFIG_FILE"
  ok "Config → ${CONFIG_FILE}"
}

# =============================================================================
# STEP 7 — Create bridge runner script
# =============================================================================
create_runner() {
  sep
  info "Creating bridge runner script..."

  mkdir -p "$CONFIG_DIR"
  mkdir -p "$(dirname "$LOG_FILE")"

  cat > "$BRIDGE_RUNNER" <<RUNNER
#!/usr/bin/env bash
# ── auto-generated by setup-bb-beeper.sh — do not edit manually ──
# Re-run setup-bb-beeper.sh to regenerate.

set -euo pipefail

# Load saved config
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

# Ensure bbctl is reachable
export PATH="\$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:\$PATH"

echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Starting sh-imessage bridge via bbctl..."

exec "\${BBCTL_BIN}" run \\
  --param "bluebubbles_url=\${TAILSCALE_URL}" \\
  --param "bluebubbles_password=\${BB_PASSWORD}" \\
  --param "imessage_platform=bluebubbles" \\
  sh-imessage
RUNNER

  chmod +x "$BRIDGE_RUNNER"
  ok "Runner → ${BRIDGE_RUNNER}"
}

# =============================================================================
# STEP 8 — LaunchAgent (auto-start + keep-alive)
# =============================================================================
setup_launch_agent() {
  sep
  info "Installing LaunchAgent (auto-start at login, keep-alive)..."

  # Gracefully unload if already running
  if launchctl list 2>/dev/null | grep -q "$LAUNCH_LABEL"; then
    launchctl unload "$LAUNCH_PLIST" 2>/dev/null || true
    info "Unloaded existing LaunchAgent"
  fi

  mkdir -p "$HOME/Library/LaunchAgents"

  cat > "$LAUNCH_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>${LAUNCH_LABEL}</string>

  <!-- Run the bridge runner script -->
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${BRIDGE_RUNNER}</string>
  </array>

  <!-- Start immediately when loaded -->
  <key>RunAtLoad</key>
  <true/>

  <!-- Restart automatically if it exits -->
  <key>KeepAlive</key>
  <true/>

  <!-- Wait 30s before restart to avoid tight crash loops -->
  <key>ThrottleInterval</key>
  <integer>30</integer>

  <!-- Log stdout + stderr -->
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>

  <!-- Minimal environment so bbctl can find binaries -->
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${HOME}</string>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.local/bin</string>
    <key>LANG</key>
    <string>en_US.UTF-8</string>
  </dict>

</dict>
</plist>
PLIST

  launchctl load "$LAUNCH_PLIST"
  ok "LaunchAgent loaded: ${LAUNCH_LABEL}"
}

# =============================================================================
# STEP 9 — Smoke test
# =============================================================================
smoke_test() {
  sep
  info "Waiting for bridge to start (15 s)..."
  sleep 15

  if launchctl list 2>/dev/null | grep -q "$LAUNCH_LABEL"; then
    ok "LaunchAgent is registered with launchd"
  else
    warn "LaunchAgent not found in launchctl list — check logs."
  fi

  if [[ -f "$LOG_FILE" ]]; then
    info "Last 5 log lines:"
    tail -5 "$LOG_FILE" | sed 's/^/   /'
  fi
}

# =============================================================================
# Summary
# =============================================================================
print_summary() {
  echo
  printf "${BOLD}${G}╔══════════════════════════════════════════════╗${N}\n"
  printf "${BOLD}${G}║   BlueBubbles + Beeper bridge is running!   ║${N}\n"
  printf "${BOLD}${G}╚══════════════════════════════════════════════╝${N}\n"
  echo
  printf "  ${BOLD}Tailscale Serve URL${N}   %s\n" "$TAILSCALE_URL"
  printf "  ${BOLD}Bridge type${N}           sh-imessage (BlueBubbles connector)\n"
  echo
  printf "  ${BOLD}Config file${N}           %s\n" "$CONFIG_FILE"
  printf "  ${BOLD}Bridge runner${N}         %s\n" "$BRIDGE_RUNNER"
  printf "  ${BOLD}LaunchAgent plist${N}     %s\n" "$LAUNCH_PLIST"
  printf "  ${BOLD}Log file${N}              %s\n" "$LOG_FILE"
  echo
  printf "  ${BOLD}Useful commands${N}\n"
  printf "    Tail logs:    tail -f %s\n" "$LOG_FILE"
  printf "    Stop bridge:  launchctl unload %s\n" "$LAUNCH_PLIST"
  printf "    Start bridge: launchctl load %s\n" "$LAUNCH_PLIST"
  printf "    Reconfigure:  bash setup-bb-beeper.sh\n"
  printf "    Force reset:  bash setup-bb-beeper.sh --reset\n"
  printf "    Uninstall:    bash uninstall-bb-beeper.sh\n"
  echo
  printf "  ${BOLD}${Y}Tip:${N} Open Beeper and your iMessage conversations\n"
  printf "  should appear within a minute or two.\n"
  echo
}

# =============================================================================
# Main
# =============================================================================
main() {
  echo
  printf "${BOLD}${B}  BlueBubbles + Beeper + Tailscale Serve Setup${N}\n"
  printf "  v%s — based on github.com/ngencokamin/sh-imessage-setup\n" "$SCRIPT_VERSION"
  echo

  check_prereqs
  install_bbctl
  login_bbctl
  setup_tailscale_serve
  get_bb_password
  save_config
  create_runner
  setup_launch_agent
  smoke_test
  print_summary
}

main "$@"
