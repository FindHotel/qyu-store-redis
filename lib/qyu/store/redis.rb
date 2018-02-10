require_relative './redis/version'
require_relative './redis/errors'
require 'json'
require 'redis'
require 'redis-namespace'

module Qyu
  module Store
    module Redis
      autoload :Adapter,                'qyu/store/redis/adapter'
      autoload :Logger,                 'qyu/store/redis/logger'
      autoload :ConfigurationValidator, 'qyu/store/redis/configuration_validator'

      class << self
        def interface
          defined?(Qyu::Store::Base) ? Qyu::Store::Base : Object
        end
      end
    end
  end

  class << self
    unless defined?(logger)
      def logger=(logger)
        @@__logger = logger
      end

      def logger
        @@__logger ||= Qyu::Store::Redis::Logger.new(STDOUT)
      end
    end
  end
end

Qyu::Config::StoreConfig.register(Qyu::Store::Redis::Adapter) if defined?(Qyu::Config::StoreConfig)
Qyu::Factory::StoreFactory.register(Qyu::Store::Redis::Adapter) if defined?(Qyu::Factory::StoreFactory)
