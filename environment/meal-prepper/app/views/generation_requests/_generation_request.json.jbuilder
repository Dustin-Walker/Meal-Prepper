json.extract! generation_request, :id, :user_id, :prompt, :raw_response, :model_used, :status, :created_at, :updated_at
json.url generation_request_url(generation_request, format: :json)
