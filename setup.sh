#!/bin/bash

bk() {
    echo "Finding path to bbctl"
    bbctl_path="$(which $bbctl_name)"
    echo "Path found! Backing up to home directory as 'bbctl.bak'"
    cp $bbctl_path ~/bbctl.bak
    echo "Backed up! Proceeding to install"
}

download() {
    echo "Getting OS"
    [[ `uname -s` == "Linux" ]] && os_type="linux" || os_type="macos"
    echo "Getting archicture"
    [[ `uname -p` == "Arm" ]] && architecture="arm64" || architecture="amd64"
    echo "Downloading latest executable"
    curl -L https://nightly.link/beeper/bridge-manager/workflows/go.yaml/main/bbctl-$os_type-$architecture.zip --output bbctl.zip
    unzip bbctl
    echo "Download successful! Installing now (this may ask for your password)"
    if $bbctl_path; then sudo rm $bbctl_path; fi
    chmod +x bbctl-$os_type-$architecture
    if [[ $architecture == 'arm' ]]; then
        if ! [ -d /Users/Shared/bbctl ]; then
            sudo mkdir /Users/Shared/bbctl
        fi
        sudo mv bbctl-$os_type-$architecture /Users/Shared/bbctl/bbctl
        bbctl_path="/Users/Shared/bbctl/bbctl"
    else
        sudo mv bbctl-$os_type-$architecture /usr/local/bin/bbctl
        bbctl_path="/usr/local/bin/bbctl"
    fi
    echo "Making sure bbctl works"
    if ! command -v bbctl &> /dev/null; then
        echo "bbctl command not found! Honestly idk why???? If you're on arm, pls ping @matchstick"
    elif ! $(bbctl  &>/dev/null); then
        echo "bbctl missing permissions! Attempting to grant now!"
        sudo chmod +x $bbctl_path
        if ! $(bbctl  &>/dev/null); then
            echo "Still not working for some reason. I guess try this script again?"
            exit 0
        else
            echo "Permissions granted!"
        fi
    else
        echo "bbctl working!"
    fi
}

add_alias() {
    if [[ $SHELL == *"zsh" ]]; then
        echo "Checking for existing zshrc"
        if [ -f "$HOME/.zshrc" ]; then
            echo "Removing previous alias if it exists"
            sed -i -e '/alias start-bb-server/d' "$HOME/.zshrc"
        fi
        echo "alias start-bb-server=\"$bb_command\"" >> $HOME/.zshrc
    else
        echo "Checking for existing bashrc"
        if [ -f "$HOME/.bashrc" ]; then
            echo "Removing previous alias if it exists"
            sed -i -e '/alias start-bb-server/d' "$HOME/.bashrc"
        fi
        echo "alias start-bb-server=\"$bb_command\"" >> $HOME/.bashrc
    fi
    alias start-bb-server="$bb_command"
}

build_command() {
    echo
    read -r -p "Use default BlueBubbles URL 'http://localhost:1234'? (correct option for most users) [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; read -p "Please enter your BlueBubbles URL: " bb_url;;
        * ) echo "Using default URL"; bb_url="http://localhost:1234";;
    esac
    read -p "Please enter your BlueBubbles password: " bb_pass
    echo
    echo "This is what I've got:"
    echo "BlueBubbles URL: $bb_url"
    echo "BlueBubbles Password: $bb_pass"
    read -r -p "Does that look correct? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, let's try this again"; build_command;;
        * ) echo "Great!";;
    esac
    if $use_tmux; then
        bb_command="tmux new-session -d -s bb-bridge bbctl run --param 'bluebubbles_url=$bb_url' --param 'bluebubbles_password=$bb_pass' --param 'imessage_platform=bluebubbles' sh-imessage"
        if $use_alias; then
            add_alias
        fi
    else
        bb_command="bbctl run --param 'bluebubbles_url=$bb_url' --param 'bluebubbles_password=$bb_pass' --param 'imessage_platform=bluebubbles' sh-imessage"
        if $use_alias; then
            add_alias
        fi
    fi
}

echo 'Checking if bbctl is currently installed'
bbctl_name="$(compgen -c | grep -i 'bbctl')"
if ! [[ -z "$bbctl_name" ]]; then
    echo 'bbctl found!'
    read -r -p "Re-install/update bbctl? (I honestly have no way to check if you're on latest) [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, no worries"; exit 0;;
        * ) echo "Proceeding";;
    esac
    bk
    logged_in="$(bbctl w 2>&1)"
    if [[ $logged_in != "You're not logged in" ]]; then
        needs_login=false
        echo 'You are logged in! Checking for existing iMessage bridge'
        bridge_exists="$(bbctl w | grep -i 'imessage')"
        if ! [[ -z $bridge_exists ]]; then
            echo "Check if bridge is running"
            running="$(bbctl w | grep -i 'sh-imessage')"
            if [[ $running == *"RUNNING"* ]]; then
                read -r -p "The process must be killed to proceed. Can I do that for you? [Y/n] " -n 1
                case "$REPLY" in 
                    n|N ) echo; echo "Alright, exiting the script"; exit 0;;
                    * ) echo "Finding bridge process";;
                esac
                bridge_ps="$(pgrep 'bbctl')"
                echo "Shutting down bridge"
                kill $bridge_ps
                while pgrep 'bbctl' &>/dev/null; do
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
        if ! [[ -z $bridge_exists ]]; then
            read -r -p "Some updates (such as the contact fix from 2/13/24) require creating a fresh bridge. Delete bridge now? [Y/n] " -n 1
            case "$REPLY" in 
                n|N ) echo; echo "Alright, no worries";;
                * ) echo "Alright, deleting bridge"; bbctl delete sh-imessage;;
            esac
        else
            echo "No existing iMessage bridge found"
        fi
    fi
    download
else
    read -r -p "bbctl not found in path! Install now? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo; echo "Alright, no worries"; exit 0;;
        * ) echo "Proceeding";;
    esac
    download
    logged_in="$(bbctl w 2>&1)"
    if [[ $logged_in == "You're not logged in" ]]; then
        echo "Please follow the prompts below to log into your Beeper account"
        bbctl login
    fi
    echo "Checking for existing iMessage bridge"
    bridge_exists="$(bbctl w | grep -i 'imessage')"
    if ! [[ -z $bridge_exists ]]; then
        read -r -p "Some updates (such as the contact fix from 2/13/24) require creating a fresh bridge. Delete bridge now? [Y/n] " -n 1
        case "$REPLY" in 
            n|N ) echo; echo "Alright, no worries";;
            * ) echo "Alright, deleting bridge"; bbctl delete sh-imessage;;
        esac
    fi
fi

if ! command -v tmux &> /dev/null; then
    read -r -p "Would you like to install tmux? It's optional, but it lets you start the bridge without needing to keep the terminal window open, so it's handy [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo "Alright, no worries"; use_tmux=false;;
        * ) echo "Cool, installing tmux now"; brew install tmux; use_tmux=true;;
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

echo "Command created! You can now start your bridge by opening a new terminal window and running the following command!"
if $use_alias; then echo "start-bb-server"; else echo "$bb_command"; fi

echo

read -r -p "Looks like we're done here! Would you like to start the bridge now? [Y/n] " -n 1
    case "$REPLY" in 
        n|N ) echo "Alright, sounds good! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)";;
        * ) echo "Alright, starting now! Have a nice day, and feel free to reach out to @matchstick in the iMessage bridge matrix room if you have any issues :)"; eval $bb_command;;
    esac