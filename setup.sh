#!/bin/bash

BBCTL_URL="https://nightly.link/beeper/bridge-manager/workflows/go.yaml/main/bbctl"
DEFAULT_BB_URL="http://localhost:1234"
BBCTL_PATH="/usr/local/bin/bbctl"

# Function to install Xcode command line tools
install_xcode_tools() {
    echo "Checking for Xcode command line tools"
    if ! xcode-select -p 1>/dev/null; then
        echo "Xcode command line tools not found. Installing now. If you see a popup asking to install, please click 'Install' and then come back here."
        xcode-select --install
        until xcode-select -p 1>/dev/null; do
            sleep 5
        done
        echo "Xcode command line tools installed"
    else
        echo "Xcode command line tools already installed"
    fi
}

# Function to check macOS version
check_macos_version() {
    echo "Checking macOS version"
    macos_version=$(sw_vers -productVersion)
    required_version="12.0.0" # Replace with the required version for Ventura
    
    if [[ $(printf '%s\n' "$required_version" "$macos_version" | sort -V | head -n1) != "$required_version" ]]; then
        echo "Your macOS version is $macos_version. BlueBubbles works best on macOS Ventura (version $required_version) and up. It is recommended to upgrade your macOS version."
    else
        echo "macOS version is $macos_version. Good to go!"
    fi
}

# Function to backup bbctl
backup_bbctl() {
    echo "Finding path to bbctl"
    bbctl_path="$(which "${bbctl_name}")"
    echo "Path found! Backing up to home directory as 'bbctl.bak'"
    cp "${bbctl_path}" ~/bbctl.bak
    echo "Backed up! Proceeding to install"
}

# Function to download and install bbctl
download_bbctl() {
    echo "Getting OS"
    [[ $(uname -s) = "Linux" ]] && os_type="linux" || os_type="macos"
    echo "Getting architecture"
    [[ $(uname -p) = "arm" ]] && architecture="arm64" || architecture="amd64"
    echo "Downloading latest executable"
    curl -L ${BBCTL_URL}-${os_type}-${architecture}.zip --output bbctl.zip
    unzip bbctl.zip
    chmod +x bbctl-${os_type}-${architecture}
    echo "Download successful! Installing now (this may ask for your password)"
    if [ -n "${bbctl_path}" ]; then sudo rm "${bbctl_path}"; fi
    if ! [ -d /usr/local/bin ]; then
        sudo mkdir /usr/local/bin
    fi
    sudo mv bbctl-${os_type}-${architecture} ${BBCTL_PATH}
    bbctl_path=${BBCTL_PATH}
    echo "Making sure bbctl works"
    if ! command -v bbctl >/dev/null 2>&1; then
        echo "bbctl command not found! Please check the installation."
        elif ! $(bbctl >/dev/null 2>&1); then
        echo "bbctl missing permissions! Attempting to grant now!"
        sudo chmod +x "${bbctl_path}"
        if ! $(bbctl >/dev/null 2>&1); then
            echo "Still not working for some reason. Please check the installation."
            exit 0
        else
            echo "Permissions granted!"
        fi
    else
        echo "bbctl working!"
    fi
}

# Function to add alias to shell
add_alias() {
    if [[ "${SHELL}" = *"zsh" ]]; then
        echo "Checking for existing zshrc"
        if [ -f "$HOME/.zshrc" ]; then
            echo "Removing previous alias if it exists"
            sed -i '' -e '/alias start-bb-server/d' "$HOME/.zshrc"
        fi
        echo "alias start-bb-server=\"${bb_command}\"" >>$HOME/.zshrc
    else
        echo "Checking for existing bashrc"
        if [ -f "$HOME/.bashrc" ]; then
            echo "Removing previous alias if it exists"
            sed -i '' -e '/alias start-bb-server/d' "$HOME/.bashrc"
        fi
        echo "alias start-bb-server=\"${bb_command}\"" >>$HOME/.bashrc
    fi
    alias start-bb-server="${bb_command}"
}

# Function to build the bb_command
build_command() {
    echo
    read -r -p "Use default BlueBubbles URL '${DEFAULT_BB_URL}'? (correct option for most users) [Y/n] " -n 1
    case "$REPLY" in
        n | N)
            echo
            read -p "Please enter your BlueBubbles URL: " bb_url
        ;;
        *)
            echo "Using default URL"
            bb_url=${DEFAULT_BB_URL}
        ;;
    esac
    read -p "Please enter your BlueBubbles password: " bb_pass
    echo
    echo "This is what I've got:"
    echo "BlueBubbles URL: ${bb_url}"
    echo "BlueBubbles Password: ${bb_pass}"
    read -r -p "Does that look correct? [Y/n] " -n 1
    case "$REPLY" in
        n | N)
            echo
            echo "Alright, let's try this again"
            build_command
        ;;
        *) echo "Great!" ;;
    esac
    if "${use_tmux}"; then
        bb_command="tmux new-session -d -s bb-bridge bbctl run --param 'bluebubbles_url=${bb_url}' --param 'bluebubbles_password=${bb_pass}' --param 'imessage_platform=bluebubbles' sh-imessage && tmux ls | grep -i 'bb-bridge'"
        echo "To attach to a running tmux session, run the command \`tmux a -t bb-bridge\`"
        if "${use_alias}"; then
            add_alias
        fi
    else
        bb_command="bbctl run --param 'bluebubbles_url=${bb_url}' --param 'bluebubbles_password=${bb_pass}' --param 'imessage_platform=bluebubbles' sh-imessage"
        if "${use_alias}"; then
            add_alias
        fi
    fi
}

# Function to create launchd agent
create_launchd_agent() {
    echo "Generating laund plist"
    cat > com.beeper.bridgemanager.imessage.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>KeepAlive</key>
        <dict>
            <key>Crashed</key>
            <true />
        </dict>
        <key>Label</key>
        <string>com.beeper.bridgemanager.imessage</string>
        <key>ProgramArguments</key>
        <array>
            <string>sh</string>
            <string>-c</string>
            <string>$bb_command</string>
        </array>
        <key>RunAtLoad</key>
        <true />
        <key>StandardErrorPath</key>
        <string>/Users/Shared/errors.log</string>
        <key>StandardOutPath</key>
        <string>/Users/Shared/out.log</string>
        <key>WorkingDirectory</key>
        <string>/Users/Shared</string>
        <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
    </dict>
</plist>
EOF
    echo "Moving launchd plist to local user LaunchAgent folder"
    mv com.beeper.bridgemanager.imessage.plist ~/Library/LaunchAgents/com.beeper.bridgemanager.imessage.plist
    
    echo "Starting launch agent"
    launchctl load -w ~/Library/LaunchAgents/com.beeper.bridgemanager.imessage.plist
    
    echo "Bridge should be starting now. If you have any issues, logs can be found at /Users/Shared/out.log and /Users/Shared/errors.log"
}

# Check if bbctl is installed
cd
echo 'Checking if bbctl is currently installed'
bbctl_name="$(compgen -c | grep -i 'bbctl')"
if ! [[ -z "${bbctl_name}" ]]; then
    echo 'bbctl found!'
    read -r -p "Re-install/update bbctl? (I honestly have no way to check if you're on latest) [Y/n] " -n 1
    case "$REPLY" in
        n | N)
            echo
            echo "Alright, no worries"
            exit 0
        ;;
        *) echo "Proceeding" ;;
    esac
    backup_bbctl
    logged_in="$(bbctl w 2>&1)"
    if [[ "${logged_in}" != "You're not logged in" ]]; then
        needs_login=false
        echo 'You are logged in! Checking for existing iMessage bridge'
        bridge_exists="$(bbctl w | grep -i 'imessage')"
        if ! [[ -z "${bridge_exists}" ]]; then
            echo "Check if bridge is running"
            running="$(bbctl w | grep -i 'sh-imessage')"
            if [[ "${running}" = *"RUNNING"* ]]; then
                read -r -p "The process must be killed to proceed. Can I do that for you? [Y/n] " -n 1
                case "$REPLY" in
                    n | N)
                        echo
                        echo "Alright, exiting the script"
                        exit 0
                    ;;
                    *) echo "Finding bridge process" ;;
                esac
                bridge_ps="$(pgrep 'bbctl')"
                echo "Shutting down bridge"
                kill "${bridge_ps}"
                while pgrep 'bbctl' >/dev/null 2>&1; do
                    sleep 1
                done
                echo "Bridge has been shut down"
            else
                echo "Bridge is not running"
            fi
            read -r -p "Some updates (such as the contact fix from 2/13/24) require creating a fresh bridge. Delete bridge now? [Y/n] " -n 1
            case "$REPLY" in
                n | N)
                    echo
                    echo "Alright, no worries"
                ;;
                *)
                    echo "Alright, deleting bridge"
                    bbctl delete sh-imessage
                ;;
            esac
        else
            echo "No existing iMessage bridge found"
        fi
        
    else
        echo "No login found! Please follow the next steps to log in"
        bbctl login
        needs_login=false
        echo "You have been logged in! Checking for existing iMessage bridge"
        bridge_exists="$(bbctl w | grep -i 'imessage')"
        if ! [[ -z "${bridge_exists}" ]]; then
            read -r -p "Some updates (such as the contact fix from 2/13/24) require creating a fresh bridge. Delete bridge now? [Y/n] " -n 1
            case "$REPLY" in
                n | N)
                    echo
                    echo "Alright, no worries"
                ;;
                *)
                    echo "Alright, deleting bridge"
                    bbctl delete sh-imessage
                ;;
            esac
        else
            echo "No existing iMessage bridge found"
        fi
    fi
    download_bbctl
else
    read -r -p "bbctl not found in path! Install now? [Y/n] " -n 1
    case "$REPLY" in
        n | N)
            echo
            echo "Alright, no worries"
            exit 0
        ;;
        *) echo "Proceeding" ;;
    esac
    download_bbctl
    logged_in="$(bbctl w 2>&1)"
    if [[ "${logged_in}" = "You're not logged in" ]]; then
        echo "Please follow the prompts below to log into your Beeper account"
        bbctl login
    fi
    echo "Checking for existing iMessage bridge"
    bridge_exists="$(bbctl w | grep -i 'imessage')"
    if ! [[ -z "${bridge_exists}" ]]; then
        read -r -p "Some updates (such as the contact fix from 2/13/24) require creating a fresh bridge. Delete bridge now? [Y/n] " -n 1
        case "$REPLY" in
            n | N)
                echo
                echo "Alright, no worries"
            ;;
            *)
                echo "Alright, deleting bridge"
                bbctl delete sh-imessage
            ;;
        esac
    fi
fi

# Check if tmux is installed and give option to use if so
if command -v tmux >/dev/null 2>&1; then
    read -r -p "Would you like to use tmux to run the bridge? It's optional, but it lets you start the bridge without needing to keep the terminal window open, so it's handy [Y/n] " -n 1
    case "$REPLY" in
        n | N)
            echo "Alright, no worries"
            use_tmux=false
        ;;
        *)
            echo "Okie dokie, using tmux"
            use_tmux=true
        ;;
    esac
else
    use_tmux=false
fi

read -r -p "Would you like to add an alias to your shell to be able to start the bridge by simply running \`start-bb-server\` instead of specifying parameters each time? [Y/n] " -n 1
case "$REPLY" in
    n | N)
        echo "Alright, sounds good!"
        use_alias=false
        echo "Time to create your run command"
    ;;
    *)
        echo "Okie dokie, setting that up now!"
        use_alias=true
    ;;
esac

build_command
install_xcode_tools
check_macos_version

echo "Command created! You can now start your bridge by opening a new terminal window and running the following command!"
if "${use_alias}"; then echo "start-bb-server"; else echo "${bb_command}"; fi

echo

read -r -p "Would you like to set up a launchd agent to start up the bridge automatically on login? [Y/n] " -n 1
case "$REPLY" in
    n | N)
        echo "Alright, sounds good!"
        echo
        read -r -p "Looks like we're done here! Would you like to start the bridge now? [Y/n] " -n 1
        case "$REPLY" in
            n | N) echo "Alright, sounds good! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)" ;;
            *)
                echo "Alright, starting now! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)"
                eval "${bb_command}"
            ;;
        esac
    ;;
    *)
        echo "Okie dokie, setting that up now!"
        create_launchd_agent
        echo "Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)"
    ;;
esac

echo


