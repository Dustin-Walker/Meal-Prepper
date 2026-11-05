class User < ApplicationRecord
  has_many :recipes, dependent: :destroy
  has_many :generation_requests, dependent: :destroy
end
