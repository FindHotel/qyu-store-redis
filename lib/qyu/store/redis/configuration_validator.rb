module Qyu
  module Store
    module Redis
      class ConfigurationValidator
        REQUIRED_ATTRIBUTES = %i(host port).freeze

        attr_reader :errors

        def initialize(config)
          @config = config
          @errors = []
        end

        def valid?
          validate
          errors.empty?
        end

        def validate
          unless @config[:url]
            REQUIRED_ATTRIBUTES.each do |attribute|
              next unless @config[attribute].nil?

              @errors << "#{attribute} must be present."
            end
          end
        end
      end
    end
  end
end
