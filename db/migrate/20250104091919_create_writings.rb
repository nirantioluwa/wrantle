class CreateWritings < ActiveRecord::Migration[8.0]
  def change
    create_table :writings do |t|
      t.string :title
      t.string :slug
      t.string :status
      t.datetime :published_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :writings, :slug, unique: true
  end
end
