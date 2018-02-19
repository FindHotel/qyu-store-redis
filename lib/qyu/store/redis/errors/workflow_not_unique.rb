module Qyu
  module Store
    module Redis
      module Errors
        # Qyu::Store::Redis::Errors::WorkflowNotUnique
        class WorkflowNotUnique < ::StandardError
          def initialize
            super('Workflow name is not unique.')
          end
        end
      end
    end
  end
end
