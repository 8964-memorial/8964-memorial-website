module ApplicationHelper
  def commenting_enabled?
    # Check environment variable first, then config
    return ENV['MEMORIAL_COMMENTING_ENABLED'] == 'true' if ENV['MEMORIAL_COMMENTING_ENABLED'].present?
    Rails.application.config.memorial['features']['commenting_enabled']
  end
end
