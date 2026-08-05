require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new do |t|
    t.pattern = "spec/**/*_spec.rb"
  end
rescue LoadError
  desc "rspec is not installed, this task is disabled"
  task :spec do
    abort "rspec is not installed. bundle install first to make sure all dependencies are installed."
  end
end

desc "Run Cookstyle tests"
task :style do
  sh "cookstyle", "--chefstyle", "--display-cop-names", "--no-color"
end

begin
  require "yard" unless defined?(YARD)
  YARD::Rake::YardocTask.new(:docs)
rescue LoadError
  puts "yard is not available. bundle install first to make sure all dependencies are installed."
end

task default: %i{spec style}
