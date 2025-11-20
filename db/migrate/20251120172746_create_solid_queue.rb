class CreateSolidQueue < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_queue_jobs)

    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps

      t.index [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtering"
      t.index [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
      t.index :class_name
      t.index :active_job_id, unique: true
      t.index :concurrency_key
    end

    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.timestamps

      t.index [:scheduled_at, :priority, :job_id], name: "index_solid_queue_scheduled_executions"
    end

    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.timestamps

      t.index [:priority, :job_id], name: "index_solid_queue_ready_executions"
      t.index :queue_name
    end

    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.bigint :process_id
      t.timestamps

      t.index [:process_id, :job_id]
    end

    create_table :solid_queue_blocked_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index [:expires_at, :concurrency_key], name: "index_solid_queue_blocked_executions"
    end

    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.text :error
      t.integer :attempts, default: 0, null: false
      t.timestamps

      t.index [:job_id, :attempts]
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.timestamps

      t.index :queue_name, unique: true
    end

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.timestamps

      t.index :last_heartbeat_at
      t.index [:kind, :last_heartbeat_at]
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at
      t.timestamps

      t.index [:key, :value], unique: true
      t.index :expires_at
    end
  end
end
