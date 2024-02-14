# sh-imessage-setup
Script to setup or upgrade [sh-imessage](https://github.com/mautrix/imessage) Beeper bridge with BlueBubbles connector

### Prerequisites

This method requires you have a Mac that can remain always on. It also requires that you have the BlueBubbles Server set up on said Mac. Note that some BlueBubbles features require MacOS version Ventura or higher. Ventura is recommended, as it has all current iMessage features, and some users have reported issues with Find My on Sonoma.

#### Upgrade Unsupported Mac

If your Mac does not officially support upgrading to Ventura or higher, you can check out OCLP (Opencore Legacy Patcher) [here](https://dortania.github.io/OpenCore-Legacy-Patcher/) to see how you can upgrade. Do note that upgrading with OCLP and then changing hardware can cause issues with iMessage. If you have trouble sending and receiving iMessages after an upgrade and hardware change, check out [this guide](https://gist.github.com/ngencokamin/6643b0253c49817ff20b7d9458fcfe06) to try and resolve it. This is what worked for me when I encountered a hardware ban.

#### BlueBubbles

For initial BlueBubbles setup, see [this guide](https://bluebubbles.app/install/). Additionally, some features also require you disable SIP to enable BlueBubbles’ Private API features. See [this page](https://docs.bluebubbles.app/private-api/) for Private API features, as well as [this page](https://docs.bluebubbles.app/private-api/installation) for a guide on how to disable SIP and enable Private API.

### Setup

1. On your Mac, clone this repo to whatever folder you would like
2. Navigate into the cloned folder with `cd sh-imessage-setup`
3. Add run permissions with `chmod +x setup.sh`
4. Run `./setup.sh` and follow the prompts from the script

### Automating Startup

At this time, this script does not include support for setting the bridge to run automatically when the Mac is rebooted. If you don't want to re-run with the command this script provides each time, follow [this guide](https://rentry.org/bb2hcep6) to create a launchd service, or [this guide](https://rentry.org/bb-cron) to set it up with cron.

### Credits

None of this would be possible without the recent hard work of Donovon Simpson and Christian Nuss, which built upon the foundational work of Tulir (Beeper Lead Architect and creator of mautrix-imessage ) and the BlueBubbles team who supported this project, along with many community members who tested and reported their findings. To acknowledge and support these incredible folks and their continued efforts, you can donate at the following links:

- Nix Genco-Kamin (oh hey, it's me): https://www.buymeacoffee.com/ngencokamin

- Tulir: https://github.com/sponsors/tulir
- Donovon Simpson: https://www.buymeacoffee.com/trek.boldly.go or https://github.com/sponsors/trek-boldly-go
- BlueBubbles Team: https://bluebubbles.app/donate
- Christian Nuss: https://github.com/cnuss (awaiting sponsor link)
