module Qyu
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
