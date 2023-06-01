class Message < ApplicationRecord
  validates :content, length: { maximum: 20 }
end
