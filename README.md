# sh-imessage-setup

Scripts to set up and maintain the [sh-imessage](https://github.com/mautrix/imessage) Beeper bridge
with a [BlueBubbles](https://bluebubbles.app) connector on macOS.

Two setup paths are available depending on your use case:

| Script | Proxy method | Best for |
|---|---|---|
| `setup-tailscale-serve.sh` | Tailscale Serve (HTTPS, tailnet-only) | Recommended — no port forwarding, auto-restart via LaunchAgent |
| `setup.sh` | Manual URL / localhost | Legacy — interactive, tmux-optional, cron-based restart |

---

## Recommended: Tailscale Serve setup

## IMPORTANT NOTICES
### Bridge Obsoletion
General recommendation these days is to use the [corten script](https://github.com/lrhodin/corten-matrix). I haven't had a chance to test it yet, but by all accounts it is more stable, does not require a mac always be running, and supports more features. Also, it can run on Linux as long as you get the hardware key from a mac. Check out the README of that repo and the imessage bridge matrix room (#imessage:maunium.net) for more info.
### Testing New Changes
My trusty 2012 Mac Mini that I was using for this bridge unceremoniously died early-mid 2026. I do not currently own a Mac for personal use. I am happy to try and troubleshoot and fix issues, but I have no way to test them myself.

### Prerequisites

All of the following must already be installed and running on the Mac that will serve iMessage:

- **macOS Monterey 12+** (Ventura recommended)
- **[BlueBubbles Server](https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest)** — running on the default port `1234`
- **[Tailscale](https://tailscale.com/download/mac)** — connected to your tailnet (standalone install recommended)
- **[Homebrew](https://brew.sh)**
- **A Beeper account** — signed into the Beeper app on this Mac

### Usage

```bash
# Clone (if you haven't already)
git clone https://github.com/ngencokamin/sh-imessage-setup.git
cd sh-imessage-setup

# First-time setup or reconfigure
bash setup-tailscale-serve.sh

# Force re-prompt all settings (new password, fresh Tailscale URL, etc.)
bash setup-tailscale-serve.sh --reset

# Tear everything down cleanly
bash uninstall.sh
```

### What the script does

1. **Checks prerequisites** — BlueBubbles on port 1234, Tailscale connected, Homebrew present
2. **Installs `bbctl`** (Beeper Bridge Manager) to `~/.local/bin/` — downloads from nightly.link, auto-selects Apple Silicon (`arm64`) or Intel (`amd64`), clears Gatekeeper quarantine
3. **Logs in to Beeper** via `bbctl login` (browser popup; skipped if already authenticated)
4. **Configures Tailscale Serve** — exposes `https://<machine>.<tailnet>.ts.net` → `localhost:1234` (HTTPS, tailnet-only, no port forwarding). This URL is for **remote clients** (phone, other devices). The bridge itself runs on the same Mac as BlueBubbles and always connects via `localhost:1234` directly.
5. **Prompts for your BlueBubbles password** and saves it to `~/.config/bb-beeper/config.env` (chmod 600). The password is passed to the BlueBubbles API as a query parameter (`?password=`).
6. **Generates a bridge runner script** at `~/.config/bb-beeper/run-bridge.sh` — includes startup diagnostics (bbctl auth, Tailscale status, BlueBubbles health check) logged before handing off to `bbctl run`
7. **Installs a LaunchAgent** (`~/Library/LaunchAgents/com.user.bb-beeper-bridge.plist`) — starts at login, auto-restarts with 30 s back-off on crash
8. **Smoke-tests** the setup and prints a summary

Configuration is saved so re-running the script is idempotent — it updates rather than rebuilding from scratch.

### Useful commands

```bash
# Full status diagnostic (health check all components)
bash debug-status.sh

# Show recent errors only
bash debug-status.sh --errors

# Follow live bridge logs
tail -f ~/Library/Logs/bb-beeper-bridge.log

# Restart the bridge
launchctl unload ~/Library/LaunchAgents/com.user.bb-beeper-bridge.plist
launchctl load  ~/Library/LaunchAgents/com.user.bb-beeper-bridge.plist

# Check Tailscale Serve status
tailscale serve status

# Verify Beeper login and bridge state
bbctl whoami
```

### File layout

```
# Repo
debug-status.sh               # on-demand diagnostic snapshot
setup-tailscale-serve.sh      # main setup script (recommended)
setup.sh                      # legacy interactive setup
uninstall.sh                  # tear everything down cleanly

# Generated at runtime
~/.config/bb-beeper/
├── config.env        # saved settings (chmod 600 — contains password)
└── run-bridge.sh     # generated runner invoked by the LaunchAgent

~/Library/LaunchAgents/
└── com.user.bb-beeper-bridge.plist   # LaunchAgent (auto-start + keep-alive)

~/Library/Logs/
└── bb-beeper-bridge.log              # stdout + stderr from the bridge
```

---

## Legacy: interactive setup (`setup.sh`)

The original script from this repo. Supports tmux, optional shell alias, and cron-based restart.
Does **not** configure Tailscale — you supply the BlueBubbles URL yourself.

### Prerequisites

- macOS Catalina minimum, Ventura recommended
- [BlueBubbles Server](https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest) installed and running
- [Homebrew](https://brew.sh)
- Xcode CLI Tools: `xcode-select --install`
- *(optional)* [tmux](https://github.com/tmux/tmux)

### Usage

```bash
chmod +x setup.sh
./setup.sh
```

Follow the interactive prompts. The script will:
- Install or update `bbctl`
- Log in to Beeper if needed
- Ask for your BlueBubbles URL and password
- Optionally set up a `start-bb-server` shell alias
- Optionally use tmux for a detached session
- Create a cron job (`~/check_and_run.sh`) for auto-restart on reboot and hourly

---

## Upgrading an unsupported Mac

If your Mac doesn't officially support Ventura or later, see
[OpenCore Legacy Patcher](https://dortania.github.io/OpenCore-Legacy-Patcher/).
After an OCLP upgrade + hardware change, if iMessage breaks, see
[this guide](https://gist.github.com/ngencokamin/6643b0253c49817ff20b7d9458fcfe06).

## BlueBubbles Private API

Some features (typing indicators, read receipts, reactions) require disabling SIP and enabling
BlueBubbles' Private API. See the [Private API docs](https://docs.bluebubbles.app/private-api/)
and [installation guide](https://docs.bluebubbles.app/private-api/installation).

---

## Credits

None of this would be possible without the work of:

- **Nix Genco-Kamin** (original script author) — https://www.buymeacoffee.com/ngencokamin
- **Tulir** (Beeper Lead Architect, mautrix-imessage) — https://github.com/sponsors/tulir
- **Donovon Simpson** — https://www.buymeacoffee.com/trek.boldly.go
- **BlueBubbles Team** — https://bluebubbles.app/donate
- **Christian Nuss** — https://github.com/cnuss
- **Cameron Aaron** — https://www.buymeacoffee.com/cameronaaron
