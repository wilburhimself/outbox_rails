begin
  require "bundler/gem_tasks"
rescue LoadError
end

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
  t.warning = false
end

# Load Rails tasks from the dummy application
APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load APP_RAKEFILE if File.exist?(APP_RAKEFILE)

task default: :test
