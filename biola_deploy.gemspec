lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'biola_deploy/version'

spec = Gem::Specification.new do |s|
  s.name = 'biola_deploy'
  s.version = BiolaDeploy::VERSION
  s.summary = 'Easy deployment for Rails applications'
  s.description = 'Designed to automate deployment of Rails applications using rake tasks'
  s.files = Dir['README.*', 'MIT-LICENSE', 'lib/**/*.rb', 'lib/tasks/*.rake']
  s.require_path = 'lib'
  s.author = 'Adam Crownoble'
  s.email = 'adam.crownoble@biola.edu'
  s.homepage = 'https://github.com/biola/biola-deploy'
end
