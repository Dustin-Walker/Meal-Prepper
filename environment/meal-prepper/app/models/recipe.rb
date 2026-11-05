class Recipe < ApplicationRecord
  belongs_to :user
  belongs_to :generation_request
  has_many :recipe_ingredients, dependent: :destroy
  has_many :recipe_tags, dependent: :destroy
end
