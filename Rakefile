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
    if hostname == "tw-mbp13-jsmith.local" or hostname.index('office.twttr.net')
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
      ENV["PATH"] = "/usr/local/bin:/usr/local/Cellar/ruby/1.9.3-p194/bin:$PATH"
    elsif hostname == "tw-mbp13-jsmith.local" or hostname.index('office.twttr.net')
      ENV["PATH"] = "/opt/twitter/share/npm/bin:$PATH"
    else
      puts "On normal boxen without weird ruby path."
      ENV["PATH"] = "/usr/local/share/npm/bin:/usr/local/bin:$PATH"
    end
  end

  if filename == "gemrc"
    ENV["GEM_SOURCES"] = "- http://rubygems.org/"
    if hostname == "tw-mbp13-jsmith.local" or hostname.index('office.twttr.net')
      puts "On work laptop, setting newfangled gem repo."
      ENV["GEM_SOURCES"] += "\n- http://gems.local.twitter.com"
    end
  end
end
