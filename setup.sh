#!/bin/bash

BBCTL_URL="https://nightly.link/beeper/bridge-manager/workflows/go.yaml/main/bbctl"
DEFAULT_BB_URL="http://localhost:1234"
BBCTL_PATH="/usr/local/bin/bbctl"

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
    unzip bbctl
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
        echo "alias start-bb-server=\"${bb_command}\"" >> $HOME/.zshrc
    else
        echo "Checking for existing bashrc"
        if [ -f "$HOME/.bashrc" ]; then
            echo "Removing previous alias if it exists"
            sed -i '' -e '/alias start-bb-server/d' "$HOME/.bashrc"
        fi
        echo "alias start-bb-server=\"${bb_command}\"" >> $HOME/.bashrc
    fi
    alias start-bb-server="${bb_command}"
}

# Function to build the bb_command
build_command() {
    echo
    read -r -p "Use default BlueBubbles URL '${DEFAULT_BB_URL}'? (correct option for most users) [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; read -p "Please enter your BlueBubbles URL: " bb_url;;
        * ) echo "Using default URL"; bb_url=${DEFAULT_BB_URL};;
    esac
    read -p "Please enter your BlueBubbles password: " bb_pass
    echo
    echo "This is what I've got:"
    echo "BlueBubbles URL: ${bb_url}"
    echo "BlueBubbles Password: ${bb_pass}"
    read -r -p "Does that look correct? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, let's try this again"; build_command;;
        * ) echo "Great!";;
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

# Function to create the cron job
create_cron_job() {
    # Create a new script that checks if the process is running and if not, it starts it
    echo '#!/bin/bash

    if ! pgrep -f "bbctl" > /dev/null
    then
        source ~/.bashrc
        start-bb-server
    fi' > ~/check_and_run.sh

    # Make the script executable
    chmod +x ~/check_and_run.sh

    # Open the crontab file and add the job
    (crontab -l 2>/dev/null; echo "@reboot ~/check_and_run.sh
    0 * * * * ~/check_and_run.sh") | crontab -
}

# Check if bbctl is installed
cd
echo 'Checking if bbctl is currently installed'
bbctl_name="$(compgen -c | grep -i 'bbctl')"
if ! [[ -z "${bbctl_name}" ]]; then
    echo 'bbctl found!'
    read -r -p "Re-install/update bbctl? (I honestly have no way to check if you're on latest) [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, no worries"; exit 0;;
        * ) echo "Proceeding";;
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
                    n|N ) echo; echo "Alright, exiting the script"; exit 0;;
                    * ) echo "Finding bridge process";;
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
                n|N ) echo; echo "Alright, no worries";;
                * ) echo "Alright, deleting bridge"; bbctl delete sh-imessage;;
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
                n|N ) echo; echo "Alright, no worries";;
                * ) echo "Alright, deleting bridge"; bbctl delete sh-imessage;;
            esac
        else
            echo "No existing iMessage bridge found"
        fi
    fi
    download_bbctl
else
    read -r -p "bbctl not found in path! Install now? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, no worries"; exit 0;;
        * ) echo "Proceeding";;
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
            n|N ) echo; echo "Alright, no worries";;
            * ) echo "Alright, deleting bridge"; bbctl delete sh-imessage;;
        esac
    fi
fi

# Check if tmux is installed
if ! command -v tmux >/dev/null 2>&1; then
    read -r -p "Would you like to install tmux? It's optional, but it lets you start the bridge without needing to keep the terminal window open, so it's handy [Y/n] " -n 1
    case "$REPLY" in
        n|N )
            echo "Alright, no worries"
            use_tmux=false
            ;;
        * )
            echo "Checking to see if you have Homebrew installed before attempting to install tmux."
            if ! command -v brew >/dev/null 2>&1; then
                read -r -p "You need Homebrew to install tmux, would you like to install that now? [Y/n] " -n 1
                case "$REPLY" in
                n | N)
                    echo "Alright, no worries. Cancelling tmux setup"
                    use_tmux=false
                    ;;
                *)
                    echo "Cool, installing brew now. Please follow the prompts"
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    echo "Installing tmux"
                    brew install tmux
                    use_tmux=true
                    ;;
                esac
            else
                brew install tmux
                use_tmux=true
            fi
    esac
else
    read -r -p "Would you like to use tmux to run the bridge? It's optional, but it lets you start the bridge without needing to keep the terminal window open, so it's handy [Y/n] " -n 1
    case "$REPLY" in
        n|N ) echo "Alright, no worries"; use_tmux=false;;
        * ) echo "Okie dokie, using tmux"; use_tmux=true;;
    esac
fi

read -r -p "Would you like to add an alias to your shell to be able to start the bridge by simply running \`start-bb-server\` instead of specifying parameters each time? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo "Alright, sounds good!"; use_alias=false; echo "Time to create your run command";;
        * ) echo "Okie dokie, setting that up now!"; use_alias=true;;
    esac

build_command
create_cron_job

echo "Command created! You can now start your bridge by opening a new terminal window and running the following command!"
if "${use_alias}"; then echo "start-bb-server"; else echo "${bb_command}"; fi

echo

read -r -p "Looks like we're done here! Would you like to start the bridge now? [Y/n] " -n 1
case "$REPLY" in
    n|N ) echo "Alright, sounds good! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)";;
    * ) echo "Alright, starting now! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)"; eval "${bb_command}";;
esac
