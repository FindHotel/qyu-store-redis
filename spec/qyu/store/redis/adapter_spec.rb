RSpec.describe Qyu::Store::Redis::Adapter do
  let(:adapter) { described_class.new(redis_config) }

  context 'class methods' do
    describe '.valid_config?' do
      context 'input config is valid' do
        it do
          expect(described_class.valid_config?({})).to be true
        end
      end
    end
  end

  context 'instance methods' do
    describe '#find_or_persist_task' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }
      let(:task) do
        {
          'name' => 'task_test',
          'queue_name' => 'queue_test',
          'payload' => { foo: 'bar' },
          'job_id' => job['id'],
          'parent_task_id' => 1010
        }
      end

      it 'returns the task id' do
        task_id = adapter.find_or_persist_task(*task.values)
        expect(task_id).not_to be_nil
      end

      it 'does not create task when it already exists' do
        task1_id = adapter.find_or_persist_task(*task.values)
        task2_id = adapter.find_or_persist_task(*task.values)

        expect(task1_id).to eq(task2_id)
      end

      it 'create new task if payload is different' do
        task1_id = adapter.find_or_persist_task(*task.values)
        task['payload'] = { bar: 'foo' }
        task2_id = adapter.find_or_persist_task(*task.values)

        expect(task1_id).not_to eq(task2_id)
      end
    end

    describe '#persist_workflow' do
      it 'stores workflow on redis' do
        workflow = adapter.persist_workflow('test-workflow', {})
        found_workflow = adapter.find_workflow_by_name('test-workflow')

        expect(found_workflow['name']).to eq(workflow['name'])
        expect(found_workflow['descriptor']).to eq(workflow['descriptor'])
      end
    end

    describe '#persist_job' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }

      it { expect { adapter.persist_job(workflow, { payload: 'foo' }) }.to change { adapter.count_jobs } }
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

    describe '#find_task' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }
      let(:task_attributes) do
        {
          'name' => 'task_test',
          'queue_name' => 'queue_test',
          'payload' => { foo: 'bar' },
          'job_id' => job['id'],
          'parent_task_id' => 1010
        }
      end

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
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }
      let(:task_attributes) do
        {
          'name' => 'task_test',
          'queue_name' => 'queue_test',
          'payload' => { foo: 'bar' },
          'job_id' => job['id'],
          'parent_task_id' => 1010
        }
      end

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
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }
      let(:task_attributes) do
        {
          'name' => 'task_test',
          'queue_name' => 'queue_test',
          'payload' => { foo: 'bar' },
          'job_id' => job['id'],
          'parent_task_id' => 1010
        }
      end

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

    describe '#find_job' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }

      it 'returns workflow' do
        found_job = adapter.find_job(job['id'])
        expect(found_job['id']).to eq(job['id'])
      end
    end

    describe '#select_jobs' do
      # TODO
    end

    describe '#select_tasks_by_job_id' do
      let(:workflow) { adapter.persist_workflow('test-workflow', {}) }
      let(:job) { adapter.persist_job(workflow, { payload: 'foo' }) }
      let(:task_attributes) do
        {
          'name' => 'task_test',
          'queue_name' => 'queue_test',
          'payload' => { foo: 'bar' },
          'job_id' => job['id'],
          'parent_task_id' => 1010
        }
      end

      context 'when task exists' do
        it 'returns task ids' do
          task1_id = adapter.find_or_persist_task(*task_attributes.values)
          task_attributes['payload'] = { bar: 'foo' }
          task2_id = adapter.find_or_persist_task(*task_attributes.values)

          tasks = adapter.select_tasks_by_job_id(job['id'])

          task_ids = tasks.map{ |task| task['id'] }
          expect(task_ids).to match_array([task1_id, task2_id])
        end
      end

      context 'when task does not exists' do
        it 'returns nil' do
          expect(adapter.select_tasks_by_job_id(111)).to be_nil
        end
      end
    end

    describe '#count_jobs' do
      before do
        workflow = adapter.persist_workflow('test-workflow', {})
        adapter.persist_job(workflow, { payload: 'foo' })
        adapter.persist_job(workflow, { payload: 'foo2' })
      end

      it { expect(adapter.count_jobs).to eq 2 }
    end

    describe '#lock_task' do
      # TODO
    end

    describe '#lock_task' do
      # TODO
    end

    describe '#renew_lock_lease' do
      # TODO
    end

    describe '#update_status' do
      # TODO
    end
  end
end
