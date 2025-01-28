class CreateSolidQueueTables < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :error_message
      t.text :error_detail
      t.string :concurrency_key
      t.datetime :created_at, null: false
    end

    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :created_at, null: false

      t.index [ :scheduled_at, :priority, :job_id ], name: "index_solid_queue_scheduled_executions_for_release"
    end

    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :created_at, null: false

      t.index [ :priority, :job_id ], name: "index_solid_queue_ready_executions_for_release"
    end

    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false
      t.bigint :process_id
      t.datetime :created_at, null: false

      t.index [ :process_id, :job_id ]
    end

    create_table :solid_queue_blocked_executions do |t|
      t.references :job, null: false
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index [ :expires_at, :concurrency_key ], name: "index_solid_queue_blocked_executions_for_maintenance"
      t.index [ :concurrency_key, :priority, :job_id ], name: "index_solid_queue_blocked_executions_for_release"
    end

    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false
      t.text :error
      t.datetime :created_at, null: false
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.datetime :created_at, null: false
    end

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.datetime :created_at, null: false
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false

      t.index [ :key, :value ], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index [ :expires_at ], name: "index_solid_queue_semaphores_on_expires_at"
    end

    add_index :solid_queue_jobs, [ :queue_name, :finished_at ], name: "index_solid_queue_jobs_for_filtering"
    add_index :solid_queue_jobs, [ :active_job_id ], name: "index_solid_queue_jobs_on_active_job_id"
    add_index :solid_queue_pauses, [ :queue_name ], unique: true
    add_index :solid_queue_processes, [ :last_heartbeat_at ]
    add_index :solid_queue_processes, [ :supervisor_id ]
  end
end
