require "sauce/parallel/test_broker"
require "parallel_tests"
require "parallel_tests/tasks"
require "parallel_tests/cli_patch"


namespace :sauce do
  task :spec, :spec_files, :concurrency, :test_options, :parallel_options do |t, args|
    ::RSpec::Core::Runner.disable_autorun!
    parallel_arguments = parse_task_args(:rspec, args)
    ParallelTests::CLI.new.run(parallel_arguments)
  end

  task :features, :files, :concurrency, :test_options, :parallel_options do |t, args|
    parallel_arguments = parse_task_args(:cucumber, args)
    ParallelTests::CLI.new.run(parallel_arguments)
  end

  namespace :install do
    task :features do
      Rake::Task["sauce:install:create_helper"].execute(:helper_type => :features)
      puts <<-ENDLINE
  The Sauce gem is now installed!

  Next steps:

  1.  Edit features/support/sauce_helper.rb with your required platforms
  2.  Set the SAUCE_USERNAME and SAUCE_ACCESS_KEY environment variables
  3.  Run your tests with 'rake sauce:features'

      ENDLINE
    end
    task :spec do
      Rake::Task["sauce:install:create_helper"].execute(:helper_type => :spec)
      spec_helper_path = "spec/spec_helper.rb"
      unless File.open(spec_helper_path) { |f| f.read.match "require \"sauce_helper\""}
        File.open("spec/spec_helper.rb", "a") do |f|
          f.write "require \"sauce_helper\""
        end
      else
        puts "WARNING - The Sauce gem is already integrated into your rspec setup"
      end
      puts <<-ENDLINE
  The Sauce gem is now installed!

  Next steps:

  1.  Edit spec/sauce_helper.rb with your required platforms
  2.  Make sure we've not mangled your spec/spec_helper.rb requiring sauce_helper
  3.  Set the SAUCE_USERNAME and SAUCE_ACCESS_KEY environment variables
  3.  Run your tests with 'rake sauce:spec'

      ENDLINE
    end

    task :create_helper, [:helper_type] do |t, args|
      path = args[:helper_type].to_sym == :features ? "features/support/sauce_helper.rb" : "spec/sauce_helper.rb"
      unless File.exists? path
        File.open(path, "w") do |f|
          f.write(Sauce::Utilities::Rake.sauce_helper)
        end
      else
        STDERR.puts "WARNING - sauce_helper has already been created."
      end
    end
  end
end

def parse_task_args(test_tool=:rspec, args)
  default = {
    :concurrency => [Sauce::TestBroker.concurrency, 20].min
  }

  if test_tool == :rspec
    default[:test_options] = '-t sauce'
    default[:files] = 'spec'
  end

  if test_tool == :cucumber
    default[:files] = 'features'
  end

  env_args = {
    :concurrency => ENV['concurrency'],
    :features => ENV['features'],
    :parallel_options => ENV['parallel_test_options'],
    :test_options => ENV['test_options'],
    :files => ENV['test_files']
  }

  concurrency = args[:concurrency] || env_args[:concurrency] || default[:concurrency]
  test_options = args[:test_options] || env_args[:test_options] || default[:test_options]
  parallel_options = args[:parallel_options] || env_args[:parallel_options] 
  files = args[:files] || env_args[:files] || default[:files]

  return_args = [
    '-n', concurrency.to_s,
    '--type'
  ]

  return_args.push 'saucerspec' if test_tool == :rspec 
  return_args.push 'saucecucumber' if test_tool == :cucumber
    
  if test_options
    return_args.push '-o'
    return_args.push test_options
  end

  return_args.push *(parallel_options.split(' ')) if parallel_options
  return_args.push files

  return return_args
end