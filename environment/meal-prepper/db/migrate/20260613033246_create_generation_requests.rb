class CreateGenerationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :generation_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.text :prompt
      t.text :raw_response
      t.string :model_used
      t.string :status

      t.timestamps
    end
  end
end
