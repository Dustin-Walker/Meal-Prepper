json.extract! user, :id, :email, :password_digest, :display_name, :created_at, :updated_at, :created_at, :updated_at
json.url user_url(user, format: :json)
