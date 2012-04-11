lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'biola_deploy/version'

spec = Gem::Specification.new do |s|
  s.name = 'biola_deploy'
  s.version = BiolaDeploy::VERSION
  s.summary = 'Easy deployment for Biola applications'
  s.description = "Designed to automate deployment of Biola's applications to it's servers using whiskey_disk friendly rake tasks"
  s.files = Dir['lib/**/*.rb', 'lib/tasks/*.rake']
  s.require_path = 'lib'
  s.author = 'Adam Crownoble'
  s.email = 'adam.crownoble@biola.edu'
  s.homepage = 'https://bitbucket.org/biola/biola-deploy'
  s.add_dependency('whiskey_disk', '>= 0.6.24')
end