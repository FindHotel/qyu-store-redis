RSpec.describe Qyu::Store::Redis::Adapter do
  let(:adapter) { described_class.new(redis_config) }

  describe '.valid_config?' do
    context 'input config is valid' do
      context 'when using url' do
        it do
          config = { url: 'redis://foo.bar' }
          expect(described_class.valid_config?(config)).to be true
        end
      end

      context 'when using separate configs' do
        it do
          expect(described_class.valid_config?(redis_config)).to be true
        end
      end
    end

    context 'input config is invalid' do
      it do
        config = redis_config
        config.delete(:host)
        expect(described_class.valid_config?(config)).to be false
      end
    end
  end

  describe 'workflow operations' do
    describe '#persist_workflow' do
      it 'stores workflow on redis' do
        workflow = adapter.persist_workflow('test-workflow', {})
        found_workflow = adapter.find_workflow_by_name('test-workflow')

        expect(found_workflow['name']).to eq(workflow['name'])
        expect(found_workflow['descriptor']).to eq(workflow['descriptor'])
      end

      it 'does not store workflows with the same name' do
        adapter.persist_workflow('test-workflow', {})

        expect { adapter.persist_workflow('test-workflow', {}) }.to raise_error(Qyu::Store::Redis::Errors::WorkflowNotUnique)
      end
    end

    describe '#find_workflow' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

      it 'returns workflow' do
        found_workflow = adapter.find_workflow(workflow['id'])

        expect(found_workflow['id']).to eq(workflow['id'])
        expect(found_workflow['descriptor']).to eq(workflow['descriptor'])
      end
    end

    describe '#find_workflow_by_name' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

      it 'returns workflow' do
        found_workflow = adapter.find_workflow_by_name(workflow['name'])

        expect(found_workflow['id']).to eq(workflow['id'])
        expect(found_workflow['descriptor']).to eq(workflow['descriptor'])
      end
    end

    describe '#delete_workflow' do
      context 'when workflow exists' do
        let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

        it 'returns true' do
          deleted = adapter.delete_workflow(workflow['id'])
          expect(deleted).to be true
        end
      end

      context 'when workflow does not exist' do
        it 'returns false' do
          deleted = adapter.delete_workflow(9999)
          expect(deleted).to be false
        end
      end
    end

    describe '#delete_workflow_by_name' do
      context 'when workflow exists' do
        let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

        it 'returns true' do
          deleted = adapter.delete_workflow_by_name(workflow['name'])
          expect(deleted).to be true
        end
      end

      context 'when workflow does not exist' do
        it 'returns false' do
          deleted = adapter.delete_workflow_by_name('foobar')
          expect(deleted).to be false
        end
      end
    end
  end

  describe 'job operations' do
    describe '#persist_job' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

      it { expect { adapter.persist_job(workflow, payload: 'foo') }.to change { adapter.count_jobs } }
    end

    describe '#find_job' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, 'payload' => 'foo') }

      it 'returns workflow' do
        found_job = adapter.find_job(job['id'])
        expect(found_job['id']).to eq(job['id'])
      end
    end

    describe '#select_jobs' do
      context 'when exists jobs' do
        let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
        let!(:job) { adapter.persist_job(workflow, 'payload' => 'foo') }
        let!(:job2) { adapter.persist_job(workflow, 'payload' => 'bar') }

        it 'returns the correct quantity' do
          selected_jobs = adapter.select_jobs(2, 0)
          expect(selected_jobs.count).to eq(2)

          selected_jobs = adapter.select_jobs(1, 0)
          expect(selected_jobs.count).to eq(1)
        end

        it 'return all values' do
          selected_job = adapter.select_jobs(1, 0).first

          expect(selected_job['payload']).not_to be_empty
          expect(selected_job['workflow']).not_to be_empty
          expect(selected_job['id']).not_to be_nil
        end
      end

      context 'when jobs does not exist' do
        it 'always returns an empty array' do
          selected_jobs = adapter.select_jobs(2, 0)
          expect(selected_jobs).to eq([])

          selected_jobs = adapter.select_jobs(1, 1)
          expect(selected_jobs).to eq([])
        end
      end
    end

    describe '#count_jobs' do
      before do
        workflow = adapter.persist_workflow('test-workflow', {})
        adapter.persist_job(workflow, payload: 'foo')
        adapter.persist_job(workflow, payload: 'foo2')
      end

      it { expect(adapter.count_jobs).to eq 2 }
    end

    describe '#delete_job' do
      context 'when job exists' do
        let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
        let!(:job) { adapter.persist_job(workflow, 'payload' => 'foo') }

        it 'returns true' do
          deleted = adapter.delete_job(job['id'])
          expect(deleted).to be true
        end
      end

      context 'when job does not exist' do
        it 'returns false' do
          deleted = adapter.delete_job(9999)
          expect(deleted).to be false
        end
      end
    end
  end

  describe 'task operations' do
    let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
    let(:job) { adapter.persist_job(workflow, payload: 'foo') }
    let(:task_attributes) do
      {
        'name' => 'task_test',
        'queue_name' => 'queue_test',
        'payload' => { foo: 'bar' },
        'job_id' => job['id'],
        'parent_task_id' => 1010
      }
    end

    describe '#find_or_persist_task' do
      it 'returns the task id' do
        task_id = adapter.find_or_persist_task(*task_attributes.values)
        expect(task_id).not_to be_nil
      end

      it 'does not create task when it already exists' do
        task1_id = adapter.find_or_persist_task(*task_attributes.values)
        task2_id = adapter.find_or_persist_task(*task_attributes.values)

        expect(task1_id).to eq(task2_id)
      end

      it 'create new task if payload is different' do
        task1_id = adapter.find_or_persist_task(*task_attributes.values)
        task_attributes['payload'] = { bar: 'foo' }
        task2_id = adapter.find_or_persist_task(*task_attributes.values)

        expect(task1_id).not_to eq(task2_id)
      end
    end

    describe '#find_task' do
      context 'when task exists' do
        let(:task_id) { adapter.find_or_persist_task(*task_attributes.values) }
        it 'returns task object' do
          expect(adapter.find_task(task_id)['id']).to eq(task_id)
        end
      end

      context 'when task does not exists' do
        let(:task_id) { 1111 }
        it 'returns nil' do
          expect(adapter.find_task(task_id)).to be_nil
        end
      end
    end

    describe '#find_task_ids_by_job_id_and_name' do
      context 'when task exists' do
        it 'returns task ids' do
          task1_id = adapter.find_or_persist_task(*task_attributes.values)
          task_attributes['payload'] = { bar: 'foo' }
          task2_id = adapter.find_or_persist_task(*task_attributes.values)

          task_ids = adapter.find_task_ids_by_job_id_and_name(job['id'], task_attributes['name'])

          expect(task_ids).to match_array([task1_id, task2_id])
        end
      end

      context 'when task does not exists' do
        it 'returns nil' do
          expect(adapter.find_task_ids_by_job_id_and_name(111, 'name')).to be_nil
        end
      end
    end

    describe '#find_task_ids_by_job_id_name_and_parent_task_ids' do
      context 'when tasks exists' do
        context 'when exists tasks for all parent_tasks_ids' do
          it 'returns task ids' do
            task1_id = adapter.find_or_persist_task(*task_attributes.values)
            task_attributes['parent_task_id'] = 2020
            task2_id = adapter.find_or_persist_task(*task_attributes.values)

            task_ids = adapter.find_task_ids_by_job_id_name_and_parent_task_ids(
              job['id'],
              task_attributes['name'],
              [1010, 2020]
            )

            expect(task_ids).to match_array([task1_id, task2_id])
          end
        end

        context 'when exists tasks for only some parent_tasks_ids' do
          it 'returns task ids' do
            task1_id = adapter.find_or_persist_task(*task_attributes.values)
            task2_id = adapter.find_or_persist_task(*task_attributes.values)

            task_ids = adapter.find_task_ids_by_job_id_name_and_parent_task_ids(
              job['id'],
              task_attributes['name'],
              [1010, 2020]
            )

            expect(task_ids).to match_array([task1_id])
          end
        end
      end

      context 'when task does not exists' do
        it 'returns nil' do
          expect(adapter.find_task_ids_by_job_id_name_and_parent_task_ids(111, 'name', [1010])).to be_nil
        end
      end
    end

    describe '#select_tasks_by_job_id' do
      context 'when task exists' do
        it 'returns task ids' do
          task1_id = adapter.find_or_persist_task(*task_attributes.values)
          task_attributes['payload'] = { bar: 'foo' }
          task2_id = adapter.find_or_persist_task(*task_attributes.values)

          tasks = adapter.select_tasks_by_job_id(job['id'])

          task_ids = tasks.map { |task| task['id'] }
          expect(task_ids).to match_array([task1_id, task2_id])
        end
      end

      context 'when task does not exists' do
        it 'returns nil' do
          expect(adapter.select_tasks_by_job_id(111)).to be_nil
        end
      end
    end

    describe '#lock_task!' do
      context 'when task exists' do
        let(:task_id) { adapter.find_or_persist_task(*task_attributes.values) }
        let(:lease_time) { 60 }

        it 'returns locked_by string and locked_until time' do
          locked = adapter.lock_task!(task_id, lease_time)

          expect(locked[0]).to be_a(String)
          expect(locked[1]).to be_within(1).of(Time.now + lease_time)
        end
      end

      context 'when task does not exists' do
        let(:task_id) { 'foobar' }

        it 'raise TaskNotFound' do
          expect { adapter.lock_task!(task_id, 60) }.to raise_error(Qyu::Store::Redis::Errors::TaskNotFound)
        end
      end
    end

    describe '#unlock_task!' do
      context 'when task exists' do
        let(:task_id) { adapter.find_or_persist_task(*task_attributes.values) }
        let(:lease_token) { adapter.lock_task!(task_id, 60)[0] }

        it 'returns true' do
          unlocked = adapter.unlock_task!(task_id, lease_token)

          expect(unlocked).to be true
        end

        it 'unlock task' do
          adapter.unlock_task!(task_id, lease_token)

          task = adapter.find_task(task_id)

          expect(task['locked_by']).to be_empty
          expect(task['locked_until']).to be_empty
        end
      end

      context 'when task does not exists' do
        let(:task_id) { 'foobar' }
        it 'returns locked_by nil and locked_until nil' do
          expect { adapter.unlock_task!(task_id, 60) }.to raise_error(Qyu::Store::Redis::Errors::TaskNotFound)
        end
      end
    end

    describe '#renew_lock_lease' do
      let(:lease_time) { 60 }

      context 'when task exists' do
        let(:task_id) { adapter.find_or_persist_task(*task_attributes.values) }
        let(:lease_token) { adapter.lock_task!(task_id, lease_time)[0] }

        it 'returns new locked_until value' do
          renewed_lock = adapter.renew_lock_lease(task_id, lease_time, lease_token)
          expect(renewed_lock).to be_within(1).of(Time.now + lease_time)
        end
      end

      context 'when task does not exists' do
        let(:task_id) { 'foobar' }
        let(:lease_token) { 'foobar' }

        it 'returns locked_by nil and locked_until nil' do
          unlocked = adapter.renew_lock_lease(task_id, lease_time, lease_token)

          expect(unlocked).to be nil
        end
      end
    end

    describe '#update_status' do
      let(:status) { 'completed' }

      context 'when task exists' do
        let(:task_id) { adapter.find_or_persist_task(*task_attributes.values) }

        it 'returns true' do
          updated = adapter.update_status(task_id, status)
          expect(updated).to be true
        end

        it 'set new status on task' do
          updated = adapter.update_status(task_id, status)

          task = adapter.find_task(task_id)

          expect(task['status']).to eq(status)
        end
      end

      context 'when task does not exists' do
        let(:task_id) { 'foobar' }

        it 'returns locked_by nil and locked_until nil' do
          expect { adapter.update_status(task_id, status) }.to raise_error(Qyu::Store::Redis::Errors::TaskNotFound)
        end
      end
    end
  end
end
