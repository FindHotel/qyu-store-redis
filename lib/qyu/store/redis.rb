require_relative "./redis/version"
require 'json'
require 'redis'
require 'redis-namespace'

module Qyu
  module Store
    module Redis
      autoload :Adapter, 'qyu/store/redis/adapter'
      autoload :Logger,  'qyu/store/redis/logger'

      class << self
        def interface
          defined?(Qyu::Store::Base) ? Qyu::Store::Base : Object
        end
      end
    end
  end
end
