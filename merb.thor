#!/usr/bin/env ruby
require 'rubygems'
require 'rubygems/dependency_installer'
require 'rubygems/uninstaller'
require 'thor'
require 'fileutils'
require 'yaml'

module MerbThorHelper
  
  private
    
  def working_dir
    @_working_dir ||= File.expand_path(options['merb-root'] || Dir.pwd)
  end
  
  def source_dir
    @_source_dir  ||= File.join(working_dir, 'src')
    create_if_missing(@_source_dir)
    @_source_dir
  end
  
  def gem_dir
    File.directory?(working_dir) ? File.join(working_dir, 'gems') : nil
  end
  
  def create_if_missing(path)
    FileUtils.mkdir(path) unless File.exists?(path)
  end
  
end

class Merb < Thor
  
  class SourcePathMissing < Exception
  end
  
  class GemPathMissing < Exception
  end
  

  class GemInstallError < Exception
  end
  
  class GemUninstallError < Exception
  end

  desc 'edge', 'Install extlib, merb-core and merb-more from git HEAD'
  method_options "--merb-root" => :optional
  def edge
    p "not implemented yet"
  end
  
  class Edge < Thor
    
    include MerbThorHelper
    
    desc 'core', 'Install extlib and merb-core from git HEAD'
    method_options "--merb-root" => :optional
    def core
      p "not implemented yet"
    end
    
    desc 'more', 'Install merb-more from git HEAD'
    method_options "--merb-root" => :optional
    def more
      p "not implemented yet"
    end
    
    desc 'plugins', 'Install merb-plugins from git HEAD'
    method_options "--merb-root" => :optional
    def plugins
      p "not implemented yet"
    end
    
  end
    
  class Source < Thor
    
    include MerbThorHelper
    
    desc 'clone REPOSITORY_URL', 'Clone a git repository into ./src'
    def clone(repository_url)
      repository_name = repository_url[/([\w+|-]+)\.git/u, 1]
      local_repo_path =  "#{source_dir}/#{repository_name}"
      
      if File.directory?(local_repo_path)
        puts "\n#{repository_name} repository exists, updating or branching instead of cloning..."
        FileUtils.cd(local_repo_path) do
       
          # to avoid conflicts we need to set a remote branch for non official repos
          #
          existing_repos = `git remote -v`.split("\n").map{|branch| branch.split(/\s+/)}
          origin_repo_url     = existing_repos.detect{|r| r.first == "origin"}.last
        
          if repository_url == origin_repo_url
            system %{
              git fetch
              git checkout master
              git rebase origin/master
            }
          # update and switch to the branch
          #
          elsif existing_repos.map{|r| r.last}.include?(repository_url)
            branch_name = repository_url[/.com\/+?(.+)\/.+\.git/u, 1]
            print "switching to remote branch: #{branch_name}\n"
            `git checkout -b #{branch_name} #{branch_name}/master`
            `git rebase #{branch_name}/master`
          
          else
            # create a new remote branch
            #
            branch_name = repository_url[/.com\/+?(.+)\/.+\.git/u, 1]
            print "Add a new remote branch: #{branch_name}\n"
            `git remote add -f #{branch_name} #{repository_url}`
            `git checkout -b#{branch_name}  #{branch_name}/master`
          end
        end
      else
        FileUtils.cd(source_dir) do
          puts "\nCloning #{repository_name} repository from #{repository_url}..."
          system("git clone --depth=1 #{repository_url} ")
        end
      end
    end
    
    desc 'update REPOSITORY_URL', 'Update a git repository from ./src'
    alias :update :clone
    
    desc 'refresh', 'Pull fresh copies of all source gems and install them'
    def refresh
      repos = Dir["#{source_dir}/*"]
      repos.each do |repo|
        FileUtils.cd(repo) do
          branch = `git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1) /'`[/\* (.+)/, 1]
          system %{ git rebase #{branch}}
        end
      end
    end
    
    # Install a particular gem from source. 
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    # 
    # thor merb:source:install merb-core
    # thor merb:source:install merb-more
    # thor merb:source:install merb-more/merb-slices
    # thor merb:source:install merb-plugins/merb_helpers
    # thor merb:source:install merb-core --merb-root ./path/to/your/app
    
    desc 'install GEM_NAME', 'Install a rubygem from (git) source'
    method_options "--merb-root" => :optional
    def install(name)
      puts "Installing #{name}..."
      gem_src_dir = File.join(source_dir, name)
      Merb.install_gem_from_src(gem_src_dir, gem_dir)
    rescue Merb::SourcePathMissing
      puts "Missing rubygem source path: #{gem_src_dir}"
    rescue Merb::GemPathMissing
      puts "Missing rubygems path: #{gem_dir}"
    rescue => e
      puts "Failed to install #{name} (#{e.message})"
    end

  end
  
  class Gems < Thor
    
    include MerbThorHelper
    
    # Install a gem and its dependencies.
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    #
    # thor merb:gems:install merb-core
    # thor merb:gems:install merb-core --version 0.9.7
    # thor merb:gems:install merb-core --merb-root ./path/to/your/app
    
    desc 'install GEM_NAME', 'Install a gem from rubygems'
    method_options "--version"   => :optional, 
                   "--merb-root" => :optional
    def install(name)
      puts "Installing #{name}..."
      opts = {}
      opts[:version] = options[:version]
      opts[:install_dir] = gem_dir if gem_dir
      Merb.install_gem(name, opts)
    rescue => e
      puts "Failed to install #{name} (#{e.message})"
    end
    
    # Update a gem and its dependencies.
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    #
    # thor merb:gems:update merb-core
    # thor merb:gems:update merb-core --merb-root ./path/to/your/app
    
    desc 'update GEM_NAME', 'Update a gem from rubygems'
    method_options "--merb-root" => :optional
    def update(name)
      puts "Updating #{name}..."
      opts = {}
      if gem_dir &&
        (gemspec_path = Dir[File.join(gem_dir, 'specifications', "#{name}-*.gemspec")].last)
        gemspec = Gem::Specification.load(gemspec_path)
        opts[:version] = Gem::Requirement.new [">=#{gemspec.version}"]
        opts[:install_dir] = gem_dir
      end
      Merb.install_gem(name, opts)
    rescue => e
      puts "Failed to update #{name} (#{e.message})"
    end
    
    # Uninstall a gem - ignores dependencies.
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    #
    # thor merb:gems:uninstall merb-core
    # thor merb:gems:uninstall merb-core --all
    # thor merb:gems:uninstall merb-core --version 0.9.7
    # thor merb:gems:uninstall merb-core --merb-root ./path/to/your/app
    
    desc 'install GEM_NAME', 'Install a gem from rubygems'
    desc 'uninstall GEM_NAME', 'Uninstall a gem'
    method_options "--version"   => :optional, 
                   "--merb-root" => :optional,
                   "--all" => :boolean
    def uninstall(name)
      puts "Uninstalling #{name}..."
      opts = {}
      opts[:ignore] = true
      opts[:all] = options[:all]
      opts[:executables] = true
      opts[:version] = options[:version]
      opts[:install_dir] = gem_dir if gem_dir
      Merb.uninstall_gem(name, opts)
    rescue => e
      puts "Failed to uninstall #{name} (#{e.message})"  
    end
    
    # Completely remove a gem - ignores dependencies.
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    #
    # thor merb:gems:wipe merb-core
    # thor merb:gems:wipe merb-core --merb-root ./path/to/your/app
    
    desc 'wipe GEM_NAME', 'Remove a gem completely'
    method_options "--merb-root" => :optional
    def wipe(name)
      puts "Wiping #{name}..."
      opts = {}
      opts[:ignore] = true
      opts[:all] = true
      opts[:executables] = true
      opts[:install_dir] = gem_dir if gem_dir
      Merb.uninstall_gem(name, opts)
    rescue => e
      puts "Failed to wipe #{name} (#{e.message})"  
    end
    
    # Remove a gem then install a fresh version.
    #
    # If a local ./gems dir is found, or --merb-root is given
    # the gems will be installed locally into that directory.
    #
    # Examples:
    #
    # thor merb:gems:refresh merb-core
    # thor merb:gems:refresh merb-core --version 0.9.7
    # thor merb:gems:refresh merb-core --merb-root ./path/to/your/app

    desc 'refresh GEM_NAME', 'Wipe then install a gem'
    method_options "--version"   => :optional,
                   "--merb-root" => :optional
    def refresh(name)
      begin
        self.wipe(name)
      rescue Merb::GemUninstallError
        puts "The gem '#{name}' wasn't installed before."
      end
      self.install(name)
    end
    
    # This task should be executed as part of a deployment setup, where
    # the deployment system runs this after the app has been installed.
    # Usually triggered by Capistrano, God...
    #
    # It will regenerate gems from the bundled gems cache for any gem
    # that has C extensions - which need to be recompiled for the target
    # deployment platform.
    
    desc 'redeploy', 'Recreate any binary gems on the target deployment platform'
    def redeploy
      require 'tempfile' # for 
      if File.directory?(specs_dir = File.join(gem_dir, 'specifications')) &&
        File.directory?(cache_dir = File.join(gem_dir, 'cache'))
        Dir[File.join(specs_dir, '*.gemspec')].each do |gemspec_path|
          unless (gemspec = Gem::Specification.load(gemspec_path)).extensions.empty?
            if File.exists?(gem_file = File.join(cache_dir, "#{gemspec.full_name}.gem"))
              gem_file_copy = File.join(Dir::tmpdir, File.basename(gem_file))
              # Copy the gem to a temporary file, because otherwise RubyGems/FileUtils
              # will complain about copying identical files (same source/destination).
              FileUtils.cp(gem_file, gem_file_copy) 
              Merb.install_gem(gem_file_copy, :install_dir => gem_dir)
              File.delete(gem_file_copy)
            end
          end
        end
      else
        puts "No application local gems directory found"
      end
    end
    
  end
  
  class << self
    
    # Default Git repositories.
    def repos
      @_repos ||= {
        'merb-core'     => "git://github.com/wycats/merb-core.git",
        'merb-more'     => "git://github.com/wycats/merb-more.git",
        'merb-plugins'  => "git://github.com/wycats/merb-plugins.git",
        'extlib'        => "git://github.com/sam/extlib.git",
        'dm-core'       => "git://github.com/sam/dm-core.git",
        'dm-more'       => "git://github.com/sam/dm-more.git"
      }
    end
    
    # Install a gem - looks remotely and locally;
    # won't process rdoc or ri options.
    def install_gem(gem, options = {})
      version = options.delete(:version)
      Gem.configuration.update_sources = false
      installer = Gem::DependencyInstaller.new(options)
      exception = nil
      begin
        installer.install gem, version
      rescue Gem::InstallError => e
        exception = e
      rescue Gem::GemNotFoundException => e
        puts "Locating #{gem} in local gem path cache..."
        spec = if version
          version = Gem::Requirement.new ["= #{version}"] unless version.is_a?(Gem::Requirement)
          Gem.source_index.find_name(gem, version).first
        else
          Gem.source_index.find_name(gem).sort_by { |g| g.version }.last
        end
        if spec && File.exists?(gem_file = "#{spec.installation_path}/cache/#{spec.full_name}.gem")
          installer.install gem_file
        end
        exception = e
      end
      if installer.installed_gems.empty? && e
        puts "Failed to install gem '#{gem}' (#{e.message})"
      end
      installer.installed_gems.each do |spec|
        puts "Successfully installed #{spec.full_name}"
      end
    end
  
    # Install a gem from source - builds and packages it first then installs it.
    def install_gem_from_src(gem_src_dir, gem_install_dir = nil)
      raise SourcePathMissing unless File.directory?(gem_src_dir)
      raise GemPathMissing if gem_install_dir && !File.directory?(gem_install_dir)
  
      gem_name = File.basename(gem_src_dir)
      gem_pkg_dir = File.expand_path(File.join(gem_src_dir, 'pkg'))
  
      # Clean and regenerate any subgems for meta gems.
      Dir[File.join(gem_src_dir, '*', 'Rakefile')].each do |rakefile|
        FileUtils.cd(File.dirname(rakefile)) { system("#{sudo}rake clobber_package; #{sudo}rake package") }             
      end
  
      # Handle the main gem install.
      if File.exists?(File.join(gem_src_dir, 'Rakefile'))
        # Remove any existing packages.
        FileUtils.cd(gem_src_dir) { system("#{sudo}rake clobber_package") }
        # Create the main gem pkg dir if it doesn't exist.
        FileUtils.mkdir_p(gem_pkg_dir) unless File.directory?(gem_pkg_dir)
        # Copy any subgems to the main gem pkg dir.
        Dir[File.join(gem_src_dir, '**', 'pkg', '*.gem')].each do |subgem_pkg|
          FileUtils.cp(subgem_pkg, gem_pkg_dir)
        end
    
        # Finally generate the main package and install it; subgems 
        # (dependencies) are local to the main package.
        FileUtils.cd(gem_src_dir) do 
          system("#{sudo}rake package")
          if package = Dir[File.join(gem_pkg_dir, "#{gem_name}-*.gem")].last
            FileUtils.cd(File.dirname(package)) do 
              options = {}
              options[:install_dir] = gem_install_dir if gem_install_dir
              return install_gem(File.basename(package), options)
            end
          else
            raise Merb::GemInstallError, "No package found for #{gem_name}"
          end
        end
      end
      raise Merb::GemInstallError, "No Rakefile found for #{gem_name}"
    end
    
    # Uninstall a gem.
    def uninstall_gem(gem, options = {})
      if options[:version] && !options[:version].is_a?(Gem::Requirement)
        options[:version] = Gem::Requirement.new ["= #{version}"]
      end
      begin
        Gem::Uninstaller.new(gem, options).uninstall
      rescue => e
        raise GemUninstallError, "Failed to uninstall #{gem}"
      end
    end
    
    # Will prepend sudo on a suitable platform.
    def sudo
      @_sudo ||= begin 
        windows = PLATFORM =~ /win32|cygwin/ rescue nil
        windows ? "" : "sudo "
      end
    end
    
  end
  
  class Tasks < Thor
    
    desc "uninstall", "Uninstall Merb's thor tasks"
    def uninstall
      `thor uninstall merb.thor`
    end

  end
  
end