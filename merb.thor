#!/usr/bin/env ruby
require 'rubygems'
require 'rubygems/dependency_installer'
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
  end
  
  def gem_dir
    File.directory?(working_dir) ? File.join(working_dir, 'gems') : nil
  end
  
end

class Merb < Thor
  
  class SourcePathMissing < Exception
  end
  
  class GemPathMissing < Exception
  end
    
  class Source < Thor
    
    include MerbThorHelper
    
    class << self
    
      def clone_shortcut(name, repos)
        define_method(name) do
          puts name
        end
      end
    
      def install_shortcut(name, gems)
        method_options "--merb-root" => :optional
        define_method(name) do
          begin
            gems.each do |name|
              puts "Installing #{name}..."
              gem_src_dir = File.join(source_dir, name)
              Merb.install_gem_from_src(gem_src_dir, gem_dir)
            end
          rescue Merb::SourcePathMissing
            puts "Missing rubygem source path: #{gem_src_dir}"
          rescue Merb::GemPathMissing
            puts "Missing rubygems path: #{gem_dir}"
          rescue => e
            puts "Failed to install Merb (#{e.message})"
          end
        end
      end
    
      def update_shortcut(name, gems)
        define_method(name) do
          puts name
        end
      end
    
      def refresh_shortcut(name, gems)
        define_method(name) do
          puts name
        end
      end
    
    end
    
    # Tasks
    
    desc 'clone REPOSITORY', 'Clone a git repository into ./src'
    def clone(repository)
      
    end
    
    # class Clone < Source
    #   
    #   desc 'merb', 'Clone extlib, merb-core and merb-more from git'
    #   clone_shortcut :merb, {}
    #   
    # end
    
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
    
    class Install < Source
      
      # Install the basic Merb gems and their dependencies.
      #
      # If a local ./gems dir is found, or --merb-root is given
      # the gems will be installed locally into that directory.
      
      desc 'merb', 'Install extlib, merb-core, and merb-more from (git) source'
      install_shortcut :merb, %w[extlib merb-core merb-more]
      
      # desc 'datamapper', 'Install extlib, dm-core and dm-more'
      # install_shortcut :datamapper, %w[extlib dm-core dm-more]
      
    end
    
    desc 'update GEM_NAME', 'Update rubygem source from git'
    def update(name)
      
    end
    
    # class Update < Source
    #   
    #   desc 'merb', 'Update Merb rubygem sources from git'
    #   update_shortcut :merb, %w[extlib merb-core merb-more]
    #   
    # end
    
    desc 'refresh', 'Pull fresh copies of all source gems and install them'
    def refresh
      
    end
    
    # class Refresh < Source
    #   
    #   desc 'merb', 'Pull fresh copies of extlib, merb-core, and merb-more install them'
    #   refresh_shortcut :merb, %w[extlib merb-core merb-more]
    #   
    # end
    
  end
  
  class Gems < Thor
    
    include MerbThorHelper
    
    # Install the basic Merb gems and their dependencies.
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
      puts "Installing #{name}"
      opts = {}
      opts[:version] = options[:version] if options[:version]
      opts[:install_dir] = gem_dir if gem_dir
      Merb.install_gem(name, opts)
    rescue => e
      puts "Failed to install #{name} (#{e.message})"
    end
    
    desc 'update GEM_NAME', 'Update a gem from rubygems'
    def update(name)
    end
    
    desc 'wipe', 'Uninstall all RubyGems related to Merb'
    def wipe
    end

    # desc 'refresh', 'Pull fresh copies of Merb and refresh all the gems'
    # def refresh
    # end
    
    # This task should be executed as part of a deployment setup, where
    # the deployment system runs this after the app has been installed.
    # Usually triggered by Capistrano, God...
    #
    # It will regenerate gems from the bundled gems cache for any gem
    # that has C extensions - which need to be recompiled for the target
    # deployment platform.
    
    desc 'deploy', 'Recreate any binary gems on the target deployment platform'
    def deploy
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
    
    class Bundle < Gems
      
      # desc 'merb', 'Bundle extlib, merb-core, and merb-more from rubygems'
      # method_options "--merb-root" => :optional
      # def merb
      #   options = {}
      #   options[:install_dir] = gem_dir if gem_dir
      #   %w[extlib merb-core merb-more].each do |name|
      #     p options
      #     # Merb.install_gem_from_src(gem_src_dir, gem_dir)
      #     
      #   end
      # end
      
    end
    
  end
  
  class << self
    
    # def components
    #   @_components ||= %w[extlib merb-core merb-more]
    # end
    
    # Default Git repositories.
    def repos
      @_repos ||= {
        'merb-core'     => "git://github.com/wycats/merb-core.git",
        'merb-more'     => "git://github.com/wycats/merb-more.git",
        'merb-plugins'  => "git://github.com/wycats/merb-plugins.git",
        'extlib'        => "git://github.com/sam/extlib.git",
        'dm-core'       => "http://github.com/sam/dm-core.git",
        'dm-more'       => "http://github.com/sam/dm-more.git"
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
        spec = version ? Gem.source_index.find_name(gem, "= #{version}").first : Gem.source_index.find_name(gem).sort_by { |g| g.version }.last
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
    
    # Will prepend sudo on a suitable platform.
    def sudo
      @_sudo ||= begin 
        windows = PLATFORM =~ /win32|cygwin/ rescue nil
        windows ? "" : "sudo "
      end
    end
    
  end
  
end