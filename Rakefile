require 'rake'

desc "Hook our dotfiles into system-standard positions."
task :install => [:submodules] do
  puts
  puts "============================================================="
  puts "Thanks to all the dotfiles on github, and the installer at"
  puts "https://github.com/skwp/dotfiles/blob/master/Rakefile"
  puts "we're about to install vim + bash configs."
  puts "============================================================="
  puts

  linkables = []
  linkables += Dir.glob('bashrc')
  linkables += Dir.glob('bash_profile')
  linkables += Dir.glob('vim/*')
  linkables += Dir.glob('vimrc')

  linkables.each do |linkable|
    file = linkable.split('/').last
    source = "#{ENV["PWD"]}/#{linkable}"
    target = "#{ENV["HOME"]}/.#{file}"

    puts "---------"
    puts "file:    #{file}"
    puts "source:  #{source}"
    puts "target:  #{target}"

    run %{ ln -s "#{source}" "#{target}" }
  end
  puts "Installed."
end

desc "Init and update submodules."
task :submodules do
  sh('git submodule update --init')
end

task :default => 'install'

private

def run(cmd)
  puts
  puts "[Installing] #{cmd}"
  `#{cmd}` unless ENV['DEBUG']
end
