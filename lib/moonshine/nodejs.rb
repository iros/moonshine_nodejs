require 'pathname'

# Define options for this plugin via the <tt>configure</tt> method
# in your application manifest:
#
#    configure(:nodejs => {:version => '0.5.4'})
#
# Moonshine will autoload plugins, just call the recipe(s) you need in your
# manifests:
#
#    recipe :nodejs

module Moonshine
  module Nodejs

    def self.included(manifest)
      manifest.class_eval do
        extend ClassMethods
      end
    end

    module ClassMethods

      def get_file(version)
        version = Gem::Version.new(version)

        if (version >= Gem::Version.new('0.0.1') &&
            version <= Gem::Version.new('0.1.9'))
          return "node-#{version}.tar.gz"
        else
          return "node-v#{version}.tar.gz"
        end
      end

      def get_folder(version)
        /([A-Za-z0-9\.\-]+).tar.gz/.match(get_file(version))[1]
      end

      def get_url(version)
        version = Gem::Version.new(version)

        if (version >= Gem::Version.new('0.5.1'))
          return "http://nodejs.org/dist/v#{version}/#{get_file(version)}"
        else
          return "http://nodejs.org/dist/#{get_file(version)}"
        end
      end

      def template_dir
         return Pathname.new(__FILE__).join('..', '..', '..', 'templates').expand_path.relative_path_from(Pathname.pwd)
      end

      def appname(app_path)
        t = app_path.split("/")
        return t.last.split(".")[0]
      end
    end

    def nodejs(user_options = {})
      # define the recipe
      # options specified with the configure method will be 
      # automatically available here in the options hash.
      #    options[:foo]   # => true

      options = {
        :version => '0.4.11'
      }.merge(user_options)

      # dependecies for install
      package 'wget',         :ensure => :installed
      package 'curl',         :ensure => :installed
      package 'cmake',        :ensure => :installed
      file '/opt/local',      :ensure => :directory
      file '/opt/local/src',  :ensure => :directory
      file '/var/log/nodejs', :ensure => :directory

      configure_command = "sh ./configure --prefix=/opt/local"
      make_command = 'make'
      install_command = 'sudo make install'
      test_command = 'make test'
      

      exec 'download node.js',
        :require  => package('wget'),
        :cwd      => '/opt/local/src',
        :command  => "wget #{get_url(options[:version])}",
        :creates  => "/opt/local/src/#{get_file(options[:version])}",
        :logoutput => true

      exec 'untar node.js',
        :require  => exec('download node.js'),
        :cwd      => '/opt/local/src',
        :command  => "tar xzf #{get_file(options[:version])}",
        :creates  => "/opt/local/src/#{get_folder(options[:version])}",
        :logoutput => true

      exec 'configure node.js',
        :require  => exec('untar node.js'),
        :cwd      => "/opt/local/src/#{get_folder(options[:version])}",
        :command  => configure_command,
        :logoutput => true

      exec 'make node.js',
        :require  => exec('configure node.js'),
        :cwd      => "/opt/local/src/#{get_folder(options[:version])}",
        :command  => make_command,
        :logoutput => true
      
      exec 'make install node.js',
        :require  => exec('make node.js'),
        :cwd      => "/opt/local/src/#{get_folder(options[:version])}",
        :command  => install_command,
        :creates  => '/opt/local/node/bin',
        :logoutput => true

      exec 'set vars',
        :require  => exec('make install node.js'),
        :command  => [
            "echo 'export PATH=/opt/local/bin:$PATH' >> ~/.profile",
            "echo 'export NODE_PATH=/opt/local:/opt/local/lib/node_modules' >> ~/.profile",
          ].join(' && '),
        :user     => 'rails',
        :group    => 'rails',
        :logoutput => true

      exec 'install npm',
        :require  => exec('set vars'),
        :command  => [
          "bash -c 'export PATH=/opt/local/bin:$PATH'",
          "bash -c 'export NODE_PATH=/opt/local:/opt/local/lib/node_modules'",
          'wget http://npmjs.org/install.sh',
          'chmod 700 install.sh',
          'clean=yes ./install.sh'
        ].join(' && '),
        :cwd      => "/opt/local/src/#{get_folder(options[:version])}",
        :logoutput => true
    end
    
  end
end
