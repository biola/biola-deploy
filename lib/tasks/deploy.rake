require 'fileutils'

namespace :deploy do
  desc 'Run the database migrations'
  task :migrate_db do
    if_rails_loads 'database migration' do
      Rake::Task['db:migrate'].invoke
    end
  end

  desc 'Reindex Solr if it exists'
  task :reindex_solr do
    if_rails_loads 'Solr reindex' do
      Rake::Task['sunspot:reindex'].invoke
    end
  end

  desc 'Precompile the asset pipeline in Rails apps 3.1 and above'
  task :precompile_assets do
    if_rails_loads 'asset precompile' do
      Rake::Task['assets:precompile'].invoke
    end
  end

  desc 'Tell NewRelic about this deployment'
  task :tell_newrelic do
    if_rails_loads 'NewRelic deployment' do
      if Rails.env.production?
        require 'new_relic/cli/command'
        require 'new_relic/cli/deployments'

        version = if defined? Version
          Version.current
        else
          `git log -1 --format=%h`.chomp # abbreviated hash of latest git commit
        end

        NewRelic::Cli::Deployments.new(revision: version).run
      else
        puts 'Canceling NewRelic deployment because: not production environment'
      end
    end
  end

  desc 'Trigger an application restart'
  task :restart_app do
    if_rails_loads 'application restart' do
      restart_file = 'tmp/restart.txt'

      Dir.chdir(app_dir) do
        if File.exists? restart_file
          FileUtils.touch restart_file
        end
      end
    end
  end

  private

  # If this is a first run and there is no database.yml (for instance)
  # this will return false
  def if_rails_loads(task_description, &block)
    error = nil

    unless defined?(Rails) && Rails.initialized?
      begin
        Rake::Task['environment'].invoke
      rescue LoadError, RuntimeError => e
        error = e.message
      end
    end

    if error
      puts "Skipping #{task_description} because: #{error}"
    else
      puts "Running #{task_description}"
      block.call
    end
  end

  def app_dir
    Rails.root.to_s
  end
end
