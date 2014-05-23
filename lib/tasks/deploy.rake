require 'fileutils'

namespace :deploy do
  desc 'Run chef-client'
  task :chef_client do
    require 'open3'

    # -n for non-interactive
    cmd = 'sudo -n chef-client'

    error_out = []
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        puts line
      end

      while line = stderr.gets
        error_out << line
      end
    end

    if error_out.any?
      puts %[Erorr when running chef-client: #{error_out.join("\n")}]
    end
  end

  desc 'Run the database migrations'
  task :migrate_db do
    if_rails_loads 'database migration' do
      require 'active_record'
      Rake::Task['db:migrate'].invoke
    end
  end

  desc 'Seed the database'
  task :seed_db do
    if_rails_loads 'database seed' do
      require 'active_record'
      Rake::Task['db:seed'].invoke
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
        require 'new_relic/cli/commands/deployments'

        if NewRelic::Agent.config[:license_key].present?
          version = if defined? Version
            Version.current
          else
            `git log -1 --format=%h`.chomp # abbreviated hash of latest git commit
          end

          NewRelic::Cli::Deployments.new(revision: version).run
        else
          puts 'Canceling NewRelic deployment because: no license key set'
        end
      else
        puts 'Canceling NewRelic deployment because: not production environment'
      end
    end
  end

  desc 'Trigger an application restart'
  task :restart_app do
    if_rails_loads 'application restart' do

      Dir.chdir(app_dir) do
        if Dir.exists? 'tmp'
          FileUtils.touch 'tmp/restart.txt'
        end
      end
    end
  end

  private

  # If this is a first run and there is no database.yml (for instance)
  # this will return false
  def if_rails_loads(task_description, &block)
    error = nil

    begin
      Rake::Task['environment'].invoke
    rescue Exception => e
      error = e.message
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
