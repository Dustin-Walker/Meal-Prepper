# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_12_230805) do
  create_table "recipes", force: :cascade do |t|
    t.integer "cook_time_minutes"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "generation_request_id", null: false
    t.text "instructions"
    t.boolean "is_published"
    t.integer "prep_time_minutes"
    t.integer "servings"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["generation_request_id"], name: "index_recipes_on_generation_request_id"
    t.index ["user_id"], name: "index_recipes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "password_digest"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "recipes", "generation_requests"
  add_foreign_key "recipes", "users"
end
