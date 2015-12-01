require 'bundler/gem_tasks'
require 'rubocop/rake_task'

desc 'Run all linters on the codebase'
task :linters do
  Rake::Task['rubocop'].invoke
end

desc 'rubocop compliancy checks'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.patterns = %w( aws-cache.gemspec bin/* lib/**/*.rb lib/*.rb Rakefile spec/*.rb )
end

task default: [:rubocop]
