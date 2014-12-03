require 'rake'
require 'erb'
require 'socket'

desc "Hook our dotfiles into system-standard positions."
task :install => [:submodules] do
  puts
  puts "============================================================="
  puts "Thanks to all the dotfiles on github, and the installer at"
  puts "https://github.com/skwp/dotfiles/blob/master/Rakefile"
  puts "we're about to install vim + bash configs."
  puts "Notes - This (theoretically) won't overwrite"
  puts "any files you already have."
  puts "============================================================="
  puts

  linkables = []
  linkables += Dir.glob('bashrc')
  linkables += Dir.glob('bash_profile.erb')
  linkables += Dir.glob('git-completion.bash')
  linkables += Dir.glob('vim')
  linkables += Dir.glob('vimrc')
  linkables += Dir.glob('gemrc.erb')
  linkables += Dir.glob('screenrc')
  linkables += Dir.glob('gitignore')
  linkables += Dir.glob('gitconfig.erb')

  linkables.each do |linkable|
    filename = linkable.split('/').last

    if linkable[-4..-1] == ".erb"
      new_filename = filename[0..-5]
      customize_scripts(new_filename)
      File.open(new_filename, 'w') do | new_file|
        new_file.write ERB.new(File.read(filename)).result(binding)
      end
      filename = new_filename
    end

    linkable = filename.sub('.erb', '')

    source = "#{ENV["PWD"]}/#{linkable}"
    target = "#{ENV["HOME"]}/.#{filename}"

    puts "---------"
    puts "filename:    #{filename}"
    puts "source:      #{source}"
    puts "target:      #{target}"

    run %{ /bin/ln -s "#{source}" "#{target}" }
  end
  puts "Installed."
end

desc "Init and update submodules."
task :submodules do
  sh('git submodule update --init')
  sh('git submodule foreach git pull origin master')
end

task :default => 'install'

private

def run(cmd)
  puts
  puts "[Installing] #{cmd}"
  `#{cmd}` unless ENV['DEBUG']
end

def customize_scripts(filename)
  hostname = Socket.gethostname
  if filename == "gitconfig"
    if hostname.index("tw-mbp13-jsmith") or hostname.index('office.twttr.net') or hostname.index('twttr.net')
      puts "On the work laptop, setting work email."
      ENV["GIT_EMAIL"] = "jsmith@twitter.com"
      ENV["GIT_USERNAME"] = "jsmith"
    else
      puts "On a personal box, using gmail account."
      ENV["GIT_EMAIL"] = "yasumoto7@gmail.com"
      ENV["GIT_USERNAME"] = "joe"
    end
  end

  if filename == "bash_profile"
    if hostname == "imac.local"
      puts "On imac with weird ruby things you've done."
      ENV["PATH"] = "/Users/joe/Python/CPython-2.7.8/bin:/Users/joe/Python/CPython-3.4.1/bin:/Users/joe/Python/PyPy-2.2.1/bin:/usr/local/bin:/usr/local/Cellar/ruby/1.9.3-p286:$PATH"
    elsif hostname.index('tw-mbp13-jsmith') or hostname.index('office.twttr.net') or hostname.index('twttr.net')
      # might want to include the below for nest machines:
      # export VIMRUNTIME=/home/jsmith/vim73/runtime
      ENV["PATH"] = "/Users/jsmith/Python/CPython-2.7.8/bin:/Users/jsmith/Python/CPython-3.4.1/bin:/Users/jsmith/Python/PyPy-2.2.1/bin:/opt/twitter/bin:/usr/local/bin:${HOME}/bin:/opt/twitter/sbin:$PATH"
      ENV["EXTRA_BASH_SOURCES"] = "source ${HOME}/.git-completion.bash;"
      ENV["TWITTER_JARGON"] = <<-eos

export LC_CTYPE=en_US.UTF-8
export CLICOLOR=1

export HISTCONTROL=erasedups
export HISTSIZE=100000
shopt -s histappend

source ${HOME}/.git-completion.bash

export PS1='[\\h \\[\\033[0;36m\\]\\W\\[\\033[0m\\]$(__git_ps1 " \\[\\033[1;32m\\](%s)\\[\\033[0m\\]")]\$ '

ulimit -n 1024

source ~/.tools-cache/setup-dottools-path.sh
        eos
    else
      puts "On normal boxen without weird ruby path."
      ENV["PATH"] = "/usr/local/share/npm/bin:/usr/local/bin:$PATH"
    end
  end

  if filename == "gemrc"
    ENV["GEM_SOURCES"] = "- http://rubygems.org/"
    if hostname == "tw-mbp13-jsmith.local" or hostname.index('office.twttr.net') or hostname.index('twttr.net')
      puts "On work laptop, setting newfangled gem repo."
      ENV["GEM_SOURCES"] += "\n- http://gems.local.twitter.com"
    end
  end
end
