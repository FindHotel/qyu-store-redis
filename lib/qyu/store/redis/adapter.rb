require 'securerandom'

module Qyu
  module Store
    module Redis
      class Adapter < Qyu::Store::Redis.interface
        TYPE = :redis

        class << self
          def valid_config?(config)
            true
          end
        end

        def initialize(config)
          init_client(config)
        end

        def find_or_persist_task(name, queue_name, payload, job_id, parent_task_id)
          task_id = nil
          existent_keys = @client.keys("task:#{name}:#{queue_name}:#{job_id}:#{parent_task_id}:*")

          existent_keys.each do |task_key|
            task = @client.hgetall(task_key)
            task_payload = parse { task['payload'] }

            if compare_payloads(task_payload, payload)
              task_id = task['id']
              break
            end
          end

          unless task_id
            task_id = SecureRandom.uuid
            key = "task:#{name}:#{queue_name}:#{job_id}:#{parent_task_id}:#{task_id}"
            @client.hmset(
              key,
              :id, task_id,
              :name, name,
              :queue_name, queue_name,
              :payload, serialize { payload },
              :job_id, job_id,
              :parent_task_id, parent_task_id
            )
          end

          task_id
        end

        def persist_workflow(name, descriptor)
          id = SecureRandom.uuid
          # TODO: Name must be uniq
          key = "workflow:#{name}:#{id}"
          @client.hmset(key, :name, name, :id, id, :descriptor, serialize { descriptor })
          { 'name' => name, 'id' => id, 'descriptor' => descriptor }
        end

        def persist_job(workflow, payload)
          id = SecureRandom.uuid
          key = "job:#{id}"
          @client.hmset(key, :workflow, serialize { workflow }, :payload, serialize { payload })
          { 'id' => id, 'workflow' => workflow, 'payload' => payload }
        end

        def find_workflow(id)
          workflow_key = @client.keys("workflow:*:#{id}").first
          return if workflow_key.nil?
          workflow = @client.hgetall(workflow_key)
          workflow['descriptor'] = parse { workflow['descriptor'] }
          workflow
        end

        def find_workflow_by_name(name)
          workflow_key = @client.keys("workflow:#{name}:*").first
          return if workflow_key.nil?
          workflow = @client.hgetall(workflow_key)
          workflow['descriptor'] = parse { workflow['descriptor'] }
          workflow
        end

        def find_task(id)
          task_key = @client.keys("task:*:*:*:*:#{id}").first
          return if task_key.nil?
          task = @client.hgetall(task_key)
          task['payload'] = parse { task['payload'] }
          task
        end

        def find_task_ids_by_job_id_and_name(job_id, name)
          task_keys = @client.keys("task:#{name}:*:#{job_id}:*:*")
          return if task_keys.empty?
          task_keys.map do |task_key|
            @client.hget(task_key, 'id')
          end.uniq
        end

        def find_task_ids_by_job_id_name_and_parent_task_ids(job_id, name, parent_task_ids)
          task_keys = parent_task_ids.flat_map do |parent_task_id|
            @client.keys("task:#{name}:*:#{job_id}:#{parent_task_id}:*")
          end
          return if task_keys.empty?
          task_keys.map do |task_key|
            @client.hget(task_key, 'id')
          end.uniq
        end

        def find_job(id)
          job = @client.hgetall("job:#{id}")
          return if job.eql?({})
          job['id'] = id
          job['payload'] = parse { job['payload'] }
          job['workflow'] = parse { job['workflow'] }
          job
        end

        def select_jobs(limit, offset, order = :asc)
          # TODO jobs embedded in them their workflows
        end

        def select_tasks_by_job_id(job_id)
          task_keys = @client.keys("task:*:*:#{job_id}:*:*")
          return if task_keys.empty?
          task_keys.map do |task_key|
            task = @client.hgetall(task_key)
            task['payload'] = parse { task['payload'] }
            task
          end
        end

        def count_jobs
          @client.keys("job:*").count
        end

        def lock_task!(id, lease_time)
          Qyu.logger.debug '[LOCK] lock_task!'

          uuid = SecureRandom.uuid
          Qyu.logger.debug "[LOCK] uuid = #{uuid}"

          locked_until = seconds_after_time(lease_time)
          Qyu.logger.debug "[LOCK] locked_until = #{locked_until}"

          key = "task:#{id}"
          task = find_task(id)
          # TODO raise task not found
          response = nil
          if task['locked_until'].eql?('') || DateTime.parse(task['locked_until']) < DateTime.now
            response = redis.hmset(key, 'locked_by', uuid, 'locked_until', locked_until).eql?('OK')
          end

          response.eql?('OK') ? [uuid, locked_until] : [nil, nil]
        end

        def unlock_task!(id, lease_token)
          key = "task:#{id}"
          task = find_task(id)
          # TODO raise task not found
          if task['locked_by'].eql?(lease_token)
            redis.hmset(key, 'locked_by', nil, 'locked_until', nil).eql?('OK')
          else
            false
          end
        end

        def renew_lock_lease(id, lease_time, lease_token)
          Qyu.logger.debug "renew_lock_lease id = #{id}, lease_time = #{lease_time}, lease_token = #{lease_token}"

          key = "task:#{id}"
          task = find_task(id)
          # TODO raise task not found
          return nil if task['locked_until'].eql?('')
          if task['locked_by'].eql?(lease_token) && DateTime.parse(task['locked_until']) > DateTime.now
            redis.hmset(key, 'locked_until', seconds_after_time(lease_time))
            locked_until
          else
            return nil
          end
        end

        def update_status(id, status)
          key = "task:#{id}"
          redis.hmset(key, 'status', status).eql?('OK')
        end

        def serialize
          yield.to_json
        end

        def parse
          JSON.parse(yield)
        end

        def transaction
          # TODO
          yield
        end

        private

        def compare_payloads(payload1, payload2)
          symbolize_hash(payload1) == symbolize_hash(payload2)
        end

        def symbolize_hash(hash)
          hash.map { |key, value| [key.to_sym, value] }.to_h
        end

        def init_client(config)
          load_config(config)
          redis_client = ::Redis.new(@@redis_configuration)
          @client = ::Redis::Namespace.new(@@redis_configuration[:namespace], :redis => redis_client)
        end

        def load_config(config)
          if config[:url]
            @@redis_configuration = { url: config[:url] }
          else
            @@redis_configuration = {
              host: config[:host],
              port: config[:port],
              password: config[:password],
              db: config[:db]
            }.compact
          end

          @@redis_configuration[:ssl_params] = config[:ssl_params] if config[:ssl_params]
          @@redis_configuration[:timeout] = config[:timeout] if config[:timeout]
          @@redis_configuration[:connect_timeout] = config[:connect_timeout] if config[:connect_timeout]
          @@redis_configuration[:read_timeout] = config[:read_timeout] if config[:read_timeout]
          @@redis_configuration[:write_timeout] = config[:write_timeout] if config[:write_timeout]
          @@redis_configuration[:namespace] = config.fetch(:namespace) { 'qyu' }
          true
        end

        def seconds_after_time(seconds, start_time = Time.now.utc)
          start_time + seconds
        end
      end
    end
  end
end

Qyu::Config::StoreConfig.register(Qyu::Store::Redis::Adapter) if defined?(Qyu::Config::StoreConfig)
Qyu::Factory::StoreFactory.register(Qyu::Store::Redis::Adapter) if defined?(Qyu::Factory::StoreFactory)
