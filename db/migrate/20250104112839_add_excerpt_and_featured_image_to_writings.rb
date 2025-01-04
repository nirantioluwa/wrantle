class AddExcerptAndFeaturedImageToWritings < ActiveRecord::Migration[8.0]
  def change
    add_column :writings, :excerpt, :text
  end
end
