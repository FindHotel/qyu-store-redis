# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'logger'

SimpleCov.start

require 'qyu'
require "qyu/store/redis"

require 'pry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end


  config.before(:each) do
    # ignore_puts
    reset_config
    clean_up_redis
  end
end

logger = Logger.new(STDOUT)
logger.level = Logger::FATAL

Qyu.logger = logger

def reset_config
  Qyu::Store::Redis::Adapter.new(redis_config)
end

def ignore_puts
  allow($stdout).to receive(:write)
end

def redis_config
  {
    type: :redis,
  }
end

def clean_up_redis
  # TODO
end
