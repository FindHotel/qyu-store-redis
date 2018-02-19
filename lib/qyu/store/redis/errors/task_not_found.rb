module Qyu
  module Store
    module Redis
      module Errors
        # Qyu::Store::Redis::Errors::TaskNotFound
        class TaskNotFound < ::StandardError
          def initialize
            super('Task not found.')
          end
        end
      end
    end
  end
end
