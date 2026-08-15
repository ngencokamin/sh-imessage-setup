#!/usr/bin/env bash
# =============================================================================
# uninstall-bb-beeper.sh
#
# Cleanly removes the BlueBubbles + Beeper bridge setup created by
# setup-bb-beeper.sh — including the LaunchAgent, config, runner script,
# and Tailscale Serve configuration.
#
# bbctl itself is NOT removed (you may use it for other bridges).
# =============================================================================

set -euo pipefail

# ── Constants (must match setup-bb-beeper.sh) ──────────────────────────────────
readonly CONFIG_DIR="$HOME/.config/bb-beeper"
readonly LOG_FILE="$HOME/Library/Logs/bb-beeper-bridge.log"
readonly LAUNCH_LABEL="com.user.bb-beeper-bridge"
readonly LAUNCH_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_LABEL}.plist"
readonly BB_PORT=1234

# ── Colours ────────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'
BOLD='\033[1m'; N='\033[0m'
info()  { printf "${B}[→]${N} %s\n" "$*"; }
ok()    { printf "${G}[✓]${N} %s\n" "$*"; }
warn()  { printf "${Y}[!]${N} %s\n" "$*"; }

# ── Confirm ────────────────────────────────────────────────────────────────────
echo
printf "${BOLD}${R}  Uninstall BlueBubbles + Beeper bridge?${N}\n"
printf "  This will stop the bridge and remove its config files.\n\n"
printf "${BOLD}Continue? [y/N]:${N} "
read -r confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
echo

# ── 1. Stop & unload LaunchAgent ──────────────────────────────────────────────
info "Stopping LaunchAgent..."
if launchctl list 2>/dev/null | grep -q "$LAUNCH_LABEL"; then
  launchctl unload "$LAUNCH_PLIST" 2>/dev/null && ok "LaunchAgent unloaded" \
    || warn "Could not unload LaunchAgent (may already be stopped)"
else
  warn "LaunchAgent not currently loaded — skipping"
fi

if [[ -f "$LAUNCH_PLIST" ]]; then
  rm -f "$LAUNCH_PLIST"
  ok "Removed: $LAUNCH_PLIST"
fi

# ── 2. Remove Tailscale Serve config ──────────────────────────────────────────
info "Removing Tailscale Serve on port ${BB_PORT}..."
tailscale serve --https=443 off 2>/dev/null \
  || sudo tailscale serve --https=443 off 2>/dev/null \
  || warn "Could not remove Tailscale Serve (may already be inactive)"
ok "Tailscale Serve removed"

# ── 3. Remove config directory ────────────────────────────────────────────────
if [[ -d "$CONFIG_DIR" ]]; then
  rm -rf "$CONFIG_DIR"
  ok "Removed: $CONFIG_DIR"
fi

# ── 4. Optionally remove log file ─────────────────────────────────────────────
if [[ -f "$LOG_FILE" ]]; then
  printf "${BOLD}Remove log file %s? [y/N]:${N} " "$LOG_FILE"
  read -r rm_logs
  if [[ "${rm_logs,,}" == "y" ]]; then
    rm -f "$LOG_FILE"
    ok "Removed: $LOG_FILE"
  else
    warn "Keeping log file: $LOG_FILE"
  fi
fi

echo
printf "${BOLD}${G}  Uninstall complete.${N}\n"
printf "  Note: bbctl itself was not removed (~/.local/bin/bbctl).\n"
printf "  To also remove it: rm ~/.local/bin/bbctl\n\n"
