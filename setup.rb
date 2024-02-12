require 'highline/import'
require 'mkmf'

def yesno(prompt = 'Continue?', default = true)
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
    a = d if a.length == 0
  end
  a == 'y'
end

def clone_and_build(contact_fix = true)
  puts 'Checking for necessary dependencies'
  if ! system 'command -v brew &> /dev/null'
    puts 'Installing homebrew'
    system '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  end
  if ! system 'command -v go &> /dev/null'
    puts 'Installing Go'
    system 'brew install go'
  end
  if ! system 'command -v ffmpeg &> /dev/null'
    puts 'Install ffmpeg'
    system 'brew install ffmpeg'
  end
  puts 'Cloning bridge manager repo'
  system "git clone #{contact_fix ? '--branch config-imessage-contacts https://github.com/ngencokamin/bridge-manager.git': 'https://github.com/beeper/bridge-manager.git'}"
  puts 'Building bbctl'
  system "cd bridge-manager && chmod +x build.sh && ./build.sh"
  puts "Moving bbctl to /usr/bin/local. This will request root permissions."
  system 'sudo mv bridge-manager/bbctl /usr/local/bin'
  puts "Making sure bbctl works"
  if system 'command -v bbctl &> /dev/null'
    puts "bbctl is working! Starting login process"
    system 'bbctl login'
  else
    puts "Error! Smth is borked!"
    exit 0
  end
end

def check_login
  system 'bbctl w  &> /dev/null'
    if $? != 'failed to get whoami: unexpected status code 401'
      puts 'bbctl not currently logged in, starting login process'
      system 'bbctl login'
    else
      puts "bbctl session found!"
    end
end

def setup_bridge()
  default_url = yesno('Would you like to use the default BlueBubbles URL? (http://localhost:1234)')
  if default_url
    bb_url = 'http://localhost:1234'
  else
    puts "Please enter the URL to use for BlueBubbles"
    bb_url = gets.chomp
  end
  puts "Please enter your BlueBubbles password"
  bb_pass = gets.chomp
  correct = yesno("Does this look right?\nURL: #{bb_url}\nPassword: #{bb_pass}")
  if correct
    puts 'Adding shortcut to .zshrc. Once this is done you can start the bridge with command `start-bb-bridge`'
    system "echo 'alias start-bb-bridge=\"bbctl run --param 'bluebubbles_url=#{bb_url}' --param 'bluebubbles_password=#{bb_pass}' --param 'imessage_platform=bluebubbles' sh-imessage\" >> ~/.zshrc && source ~/.zshrc"
    puts "All done! Have a nice day :)"
  else
    setup_bridge
  end

end

puts 'Checking if bbctl is already in path'

if system 'command -v bbctl &> /dev/null'
    puts 'bbctl found in path, proceeding!'
    check_login
elsif !Dir.glob("#{__dir__}/bbctl*").empty?
    puts "Found bbctl executable in folder, adding permissions and moving to path. This will request root permissions."
    system "chmod +x bbctl* && sudo mv bbctl* /usr/local/bin/bbctl"
    puts "Making sure bbctl works"
    if system 'command -v bbctl &> /dev/null'
      check_login
      setup_bridge
    else
      puts "Error! bbctl not found in path! Please try again"
      exit 0
    end
else
    should_build = yesno('bbctl executable not found! Clone and build now?')
    if should_build
      contacts_fork = yesno('Would you like to download the fork with fixed contact naming and photos? https://github.com/ngencokamin/bridge-manager/tree/config-imessage-contacts')
      clone_and_build(contacts_fork)
      setup_bridge
    else
      puts "Script exiting. Please download the official bbctl build for your system at https://github.com/beeper/bridge-manager/actions/runs/7686952215. Alternately, you can install the following PR build to fix contact name and photo issues https://github.com/beeper/bridge-manager/actions/runs/7865095259?pr=17"
      puts "Once that's done, copy it into this folder and run the script again"
      exit 0
    end
end