# sh-imessage-setup
Script to setup or upgrade [sh-imessage](https://github.com/mautrix/imessage) Beeper bridge with BlueBubbles connector

### Prerequisites
Brew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

Xcode CLI Tools: xcode-select --install 

Blue Bubbles Server setup and running: brew install --cask bluebubbles or https://github.com/BlueBubblesApp/bluebubbles-server/releases/latest

### Installation

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

The setup script includes a function, `create_cron_job`, which automates the startup of the Bridge script. This function creates a new bash script, `check_and_run.sh`, that checks if the `bbctl` process is running. If it's not, the script sources the `~/.bashrc` file and starts the server using the `start-bb-server` command.

The `create_cron_job` function also adds a new job to the crontab to run `check_and_run.sh` at system startup and every hour thereafter. This ensures that if the Bridge script encounters an issue and stops running, it will automatically restart. The cron job is set up as follows:

- At system reboot, the `check_and_run.sh` script is executed.
- Every hour, on the hour, the `check_and_run.sh` script is executed again.

This self-recovery mechanism ensures the continuous operation of the Bridge script.

### Fuction by Function breakdown:

Functions
install_xcode_tools()
This function checks if Xcode command line tools are installed on the system. If not, it installs them. This is necessary for some of the operations in the script.

check_macos_version()
This function checks the version of macOS on the system. If the version is less than the required version for BlueBubbles, it recommends the user to upgrade their macOS version.

backup_bbctl()
This function finds the path to the bbctl binary, if it exists, and backs it up to the home directory as bbctl.bak.

download_bbctl()
This function downloads the latest bbctl binary for the system's OS and architecture, unzips it, makes it executable, and moves it to /usr/local/bin. It also checks if the bbctl command works after installation.

add_alias()
This function adds an alias to the user's shell (either .zshrc or .bashrc) to start the BlueBubbles server. The alias is start-bb-server.

build_command()
This function builds the command to start the BlueBubbles server. It asks the user for their BlueBubbles URL and password, and builds the command accordingly. If the user chooses to use tmux, it includes tmux in the command.

ping_bluebubbles_server()
This function pings the BlueBubbles server at the provided URL to check if it's running and responding to requests.

create_cron_job()
This function creates a cron job that checks if the bbctl process is running at system startup and every hour thereafter. If it's not running, it starts it. This ensures that the server will automatically restart if it stops for any reason.

### Credits

None of this would be possible without the recent hard work of Donovon Simpson and Christian Nuss, which built upon the foundational work of Tulir (Beeper Lead Architect and creator of mautrix-imessage ) and the BlueBubbles team who supported this project, along with many community members who tested and reported their findings. To acknowledge and support these incredible folks and their continued efforts, you can donate at the following links:

- Nix Genco-Kamin (oh hey, it's me): https://www.buymeacoffee.com/ngencokamin

- Tulir: https://github.com/sponsors/tulir
- Donovon Simpson: https://www.buymeacoffee.com/trek.boldly.go or https://github.com/sponsors/trek-boldly-go
- BlueBubbles Team: https://bluebubbles.app/donate
- Christian Nuss: https://github.com/cnuss (awaiting sponsor link)
- Cameron Aaron: https://www.buymeacoffee.com/cameronaaron or 
https://github.com/sponsors/cameronaaron

