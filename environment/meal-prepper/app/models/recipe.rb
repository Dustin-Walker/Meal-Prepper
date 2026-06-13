class Recipe < ApplicationRecord
  belongs_to :user
  belongs_to :generation_request
end
