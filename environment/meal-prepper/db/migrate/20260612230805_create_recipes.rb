class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :generation_request, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :servings
      t.integer :prep_time_minutes
      t.integer :cook_time_minutes
      t.text :instructions
      t.boolean :is_published

      t.timestamps
    end
  end
end
