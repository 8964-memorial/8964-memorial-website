class Message < ApplicationRecord
  validates :name, presence: true, length: { maximum: 50 }
  validates :content, presence: true, length: { maximum: 20 }
  
  # Sanitize input to prevent XSS
  before_save :sanitize_input
  
  private
  
  def sanitize_input
    self.name = ActionController::Base.helpers.sanitize(name) if name.present?
    self.content = ActionController::Base.helpers.sanitize(content) if content.present?
  end
end
