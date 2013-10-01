require 'fileutils'
require 'uri'

namespace :deploy do
  desc 'Run the database migrations'
  task :migrate_db => :environment do
    puts 'migrating the database...'
    Rake::Task['db:migrate'].invoke
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

  desc 'Trigger a Passenger restart'
  task :restart_app => :environment do
    restart_file = 'tmp/restart.txt'

    puts 'restarting the app...'
    Dir.chdir(app_dir) do
      make_globally_writable restart_file if File.exists? restart_file
      FileUtils.touch restart_file
    end
  end

  desc 'Run all deployment tasks'
  task :post_deploy => [:migrate_db, :reindex_solr, :precompile_assets, :tell_newrelic, :restart_app]

  private

  def app_dir
    Rails.root.to_s
  end

  def make_globally_writable(file)
    permissions = File.directory?(file) ? 777 : 666
    system "sudo chmod #{permissions} #{file}"
  end
end
