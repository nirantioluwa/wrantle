class AddConcurrencyKeyToSolidQueueJobs < ActiveRecord::Migration[8.0]
  def change
    # Add concurrency_key column if it doesn't exist
    # This column was missing from the initial table creation in production
    unless column_exists?(:solid_queue_jobs, :concurrency_key)
      add_column :solid_queue_jobs, :concurrency_key, :string
      add_index :solid_queue_jobs, :concurrency_key
    end
  end
end
