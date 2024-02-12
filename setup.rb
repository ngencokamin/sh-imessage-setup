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

puts 'Checking if bbctl is already in path'

# yesno("Do it?", true)

if system 'command -v bbctl &> /dev/null'
    puts 'bbctl found in path, proceeding!'
    if system('bbctl w &> /dev/null') == 'failed to get whoami: unexpected status code 401'
        puts 'bbctl not currently logged in, starting login process'
        system('bbctl login')
    else
        puts "bbctl session found!"
        puts "Checking for existing imessage bridge"
    end
else
    puts 'no'
end