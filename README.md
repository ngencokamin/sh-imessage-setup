# sh-imessage-setup
Script to setup or upgrade [sh-imessage](https://github.com/mautrix/imessage) Beeper bridge with BlueBubbles connector

### Prerequisites


##### Required

- A computer running MacOS which will be left always running with the following software:
 	- MacOS Catalina minimum, Ventura recommended (more recent versions enable more features, reference the [BlueBubbles documentation](https://docs.bluebubbles.app/server#supported-mac-devices)).
 	- [BlueBubbles Server](https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest) installed and running.

##### Optional
- [tmux](https://github.com/tmux/tmux?tab=readme-ov-file#installation)
  - This is not *required* to use this script, but provides additional benefits in launching the bridge post-install.


#### Upgrade Unsupported Mac

If your Mac does not officially support upgrading to Ventura or higher, you can check out OCLP (Opencore Legacy Patcher) [here](https://dortania.github.io/OpenCore-Legacy-Patcher/) to see how you can upgrade. Do note that upgrading with OCLP and then changing hardware can cause issues with iMessage. If you have trouble sending and receiving iMessages after an upgrade and hardware change, check out [this guide](https://gist.github.com/ngencokamin/6643b0253c49817ff20b7d9458fcfe06) to try and resolve it. This is what worked for me when I encountered a hardware ban.

#### BlueBubbles

For initial BlueBubbles setup, see [this guide](https://bluebubbles.app/install/). Additionally, some features also require you disable SIP to enable BlueBubbles’ Private API features. See [this page](https://docs.bluebubbles.app/private-api/) for Private API features, as well as [this page](https://docs.bluebubbles.app/private-api/installation) for a guide on how to disable SIP and enable Private API.

### Setup

1. Open a new terminal window on your Mac
2. Run `git clone https://github.com/ngencokamin/sh-imessage-setup.git` to clone this repo to your device
3. Navigate into the cloned folder with `cd sh-imessage-setup`
4. Add run permissions with `chmod +x setup.sh`
5. Run `./setup.sh` and follow the prompts from the script

### Automating Startup

At this time, this script does not include support for setting the bridge to run automatically when the Mac is rebooted. If you don't want to re-run with the command this script provides each time, follow [this guide](https://rentry.org/bb2hcep6) to create a launchd service, or [this guide](https://rentry.org/bb-cron) to set it up with cron.

### Credits

None of this would be possible without the recent hard work of Donovon Simpson and Christian Nuss, which built upon the foundational work of Tulir (Beeper Lead Architect and creator of mautrix-imessage ) and the BlueBubbles team who supported this project, along with many community members who tested and reported their findings. To acknowledge and support these incredible folks and their continued efforts, you can donate at the following links:

- Nix Genco-Kamin (oh hey, it's me): https://www.buymeacoffee.com/ngencokamin

- Tulir: https://github.com/sponsors/tulir
- Donovon Simpson: https://www.buymeacoffee.com/trek.boldly.go or https://github.com/sponsors/trek-boldly-go
- BlueBubbles Team: https://bluebubbles.app/donate
- Christian Nuss: https://github.com/cnuss (awaiting sponsor link)
