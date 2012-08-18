require 'whiskey_disk/helpers'
require 'fileutils'
require 'uri'

namespace :deploy do
  desc 'Create a new user for the app'
  task :create_user => :environment do
    unless app_user_exists?
      puts "creating user #{app_username}..."
      system "sudo useradd --system --shell /bin/false --home #{app_dir} #{app_username}"
    end
  end

  desc 'Put the logs in /var/log and sym link to ./logs'
  task :prepare_logs => :environment do
    puts 'preparing logs...'

    # ensure the base log directory for our apps exists
    system("sudo mkdir #{base_log_dir}") unless Dir.exists?(base_log_dir)

    # create the app's log directory under the base directory and make the app user the owner
    system "sudo mkdir #{app_log_dir}" unless Dir.exists?(app_log_dir)
    chown_to_app_user app_log_dir

    # symbolic link the system log directory to the app log directory
    Dir.chdir(app_dir) do
      system('rm -rf log') if Dir.exists?('log')
      FileUtils.ln_s(app_log_dir, 'log')
    end
  end

  desc 'Create the ./tmp directory with the correct permissions'
  task :prepare_tmp => :environment do
    puts 'preparing /tmp directory...'
    Dir.chdir(app_dir) do
      Dir.mkdir('tmp') unless Dir.exists?('tmp')
      make_globally_writable 'tmp'
      chown_to_app_user 'tmp'
    end
  end

  desc 'Set permissions on ./public'
  task :prepare_public => :environment do
    Dir.chdir(app_dir) do
      make_globally_writable 'public'
      chown_to_app_user 'public'
    end
  end

  desc 'Configure Nginx to serve the app'
  task :setup_webserver => :environment do
    File.open(webserver_app_config_file, 'w') do |file|
      config = if server?
"
server {
 listen                   80;
 listen                   443 ssl;
 server_name              #{app_url.host};
 server_name              #{app_url.host.split('.').first}.#{hostname};

 index                    index.html index.htm;

 location / {
  root                    #{app_public_dir};
  passenger_set_cgi_param HTTP_X_FORWARDED_PROTO $scheme;
  passenger_enabled       on;
 }
}
"
      else
"
location #{app_url.path} {
 passenger_enabled       on;
 passenger_base_uri      #{app_url.path};
 passenger_user          #{app_username};
 passenger_group         #{app_username};
 passenger_set_cgi_param HTTP_X_FORWARDED_PROTO $scheme;
}
"
      end

      file.write config
    end

    # sym link the location path
    if location?
      FileUtils.ln_s(File.join(app_dir, 'public'), File.join(web_root_dir, app_url.path))
    end
  end

  desc 'Create the database'
  task :create_db do
    host = db_config['host'] || 'localhost'

    if db_config['adapter'] =~ /mysql/
      client = Mysql2::Client.new(:host => host, :username => ENV['DB_CREATE_USERNAME'], :password => ENV['DB_CREATE_PASSWORD'])
      db = db_config['database']
      user = db_config['username']
      password = db_config['password']

      client.query 'USE mysql'
      client.query "CREATE DATABASE IF NOT EXISTS #{db}"
      client.query "GRANT ALL PRIVILEGES ON #{db}.* TO '#{user}'@'%' IDENTIFIED BY '#{password}'"
    end
  end

  desc 'Run the database migrations'
  task :migrate_db => :environment do
    puts 'migrating the database...'
    Rake::Task['db:migrate'].invoke
  end

  desc 'TODO'
  task :setup_solr do
    # TODO
  end

  desc 'Reindex Solr if it exists'
  task :reindex_solr do
    if Rake::Task.task_defined? 'sunspot:reindex'
      puts 'reindexing Solr...'
      Rake::Task['sunspot:reindex'].invoke
    end
  end

  desc 'Precompile the asset pipeline in Rails apps 3.1 and above'
  task :precompile_assets do
    if Rake::Task.task_defined? 'assets:precompile'
      puts 'precompiling assets...'
      Rake::Task['assets:precompile'].invoke
    end
  end

  desc 'Trigger a Passenger restart'
  task :restart_app => :environment do
    restart_file = 'tmp/restart.txt'

    puts 'restarting the app...'
    Dir.chdir(app_dir) do
      make_globally_writable restart_file if File.exists? restart_file
      FileUtils.touch restart_file
    end
  end

  desc 'Tell NewRelic about this deployment'
  task :tell_newrelic => :environment do
    require 'new_relic/command'
    require 'new_relic/commands/deployments'

    version = if defined? Version
      Version.current
    else
      `git log -1 --format=%h`.chomp # abbreviated hash of latest git commit
    end

    NewRelic::Command::Deployments.new :revision => version
  end

  desc 'Run all setup tasks'
  task :post_setup => [:create_db, :create_user, :prepare_logs, :prepare_tmp, :prepare_public, :setup_webserver, :setup_solr] 

  desc 'Run all deployment tasks'
  task :post_deploy => [:migrate_db, :reindex_solr, :precompile_assets, :tell_newrelic, :restart_app]

  private
  def web_root_dir
    ENV['WEB_ROOT']
  end

  def app_dir
    Rails.root.to_s
  end

  def app_public_dir
    File.join(app_dir, 'public')
  end

  def app_url
    URI.parse ENV['APP_URL']
  end
  alias :app_uri :app_url

  def url_type
    if app_url.path.to_s.gsub('/', '') == ''
      :server
    else
      :location
    end
  end

  def server?
    url_type == :server
  end

  def location?
    url_type == :location
  end

  def app_name
    ENV['APP_NAME']
  end

  def app_username
    app_name
  end

  def hostname
    system 'hostname --long'
  end

  def webserver_app_config_file
    "/etc/nginx/sites/#{app_name}.#{url_type}.conf"
  end

  def base_log_dir
    '/var/log/rails'
  end

  def app_log_dir
    File.join(base_log_dir, app_name)
  end

  def app_user_exists?
    !!system("id #{app_username}")
  end

  def chown_to_app_user(file)
    system "sudo chown -R #{app_username}:#{app_username} #{file}"
  end

  def make_globally_writable(file)
    permissions = File.directory?(file) ? 777 : 666
    system "sudo chmod #{permissions} #{file}"
  end

  def db_config
    return @db_config unless @db_config.nil?

    database_yml_path = File.join(changes_file_root, 'config', 'database.yml')
    @db_config = YAML::load(File.open(database_yml_path))[ENV['RAILS_ENV']]
  end
end
