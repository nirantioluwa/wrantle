class CreateVerificationCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :verification_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.string :verification_type, null: false # 'admin' or 'staff'
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :verification_codes, :code, unique: true
  end
end
