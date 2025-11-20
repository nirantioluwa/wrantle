class AddNameToSolidQueueProcesses < ActiveRecord::Migration[8.0]
  def change
    # Only add the column if it doesn't exist (idempotent)
    unless column_exists?(:solid_queue_processes, :name)
      # Add the name column with a temporary default to handle existing rows
      add_column :solid_queue_processes, :name, :string, null: false, default: ""

      # Update any existing rows with a generated name
      reversible do |dir|
        dir.up do
          execute <<-SQL
            UPDATE solid_queue_processes
            SET name = kind || '-' || id::text
            WHERE name = ''
          SQL
        end
      end

      # Remove the default constraint (we only needed it for existing rows)
      change_column_default :solid_queue_processes, :name, from: "", to: nil

      # Add unique index on name
      add_index :solid_queue_processes, :name, unique: true
    end
  end
end
