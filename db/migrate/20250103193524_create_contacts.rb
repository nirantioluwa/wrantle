class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :contact_type
      t.text :message
      t.date :preferred_date
      t.time :preferred_time
      t.string :status

      t.timestamps
    end
  end
end
