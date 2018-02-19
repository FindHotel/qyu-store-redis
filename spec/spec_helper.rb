# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'logger'

SimpleCov.start

require 'qyu/store/redis'

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
    host: ENV.fetch('QYU_REDIS_HOST', 'localhost'),
    port: ENV.fetch('QYU_REDIS_PORT', 6379),
    password: ENV['QYU_REDIS_PASSWORD'],
    db: ENV.fetch('QYU_REDIS_DB', 14), # Default db to 14 so we don't screw up with real data. (Even though we use namespace)
    namespace: ENV.fetch('QYU_REDIS_NAMESPACE', 'qyu_test')
  }
end

def clean_up_redis
  redis = Redis.new(redis_config)
  namespaced_redis = Redis::Namespace.new(redis_config[:namespace], redis: redis)
  if (keys = namespaced_redis.keys) && !keys.empty?
    namespaced_redis.del(keys)
  end
end
