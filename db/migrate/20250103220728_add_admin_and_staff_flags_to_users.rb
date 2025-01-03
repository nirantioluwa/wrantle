class AddAdminAndStaffFlagsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_admin, :boolean, null: false, default: false
    add_column :users, :is_staff, :boolean, null: false, default: false
  end
end
