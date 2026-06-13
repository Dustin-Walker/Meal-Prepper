json.extract! recipe, :id, :user_id, :generation_request_id, :title, :description, :servings, :prep_time_minutes, :cook_time_minutes, :instructions, :is_published, :created_at, :updated_at
json.url recipe_url(recipe, format: :json)
