require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "commenting_enabled? returns true when config is true" do
    # Mock the config
    Rails.application.config.memorial = { features: { commenting_enabled: true } }
    
    # Clear any environment variable
    ENV.delete('MEMORIAL_COMMENTING_ENABLED')
    
    assert commenting_enabled?
  end

  test "commenting_enabled? returns false when config is false" do
    # Mock the config
    Rails.application.config.memorial = { features: { commenting_enabled: false } }
    
    # Clear any environment variable
    ENV.delete('MEMORIAL_COMMENTING_ENABLED')
    
    assert_not commenting_enabled?
  end

  test "commenting_enabled? prioritizes environment variable over config" do
    # Set config to false but env var to true
    Rails.application.config.memorial = { features: { commenting_enabled: false } }
    ENV['MEMORIAL_COMMENTING_ENABLED'] = 'true'
    
    assert commenting_enabled?
    
    # Clean up
    ENV.delete('MEMORIAL_COMMENTING_ENABLED')
  end

  test "commenting_enabled? returns false when env var is not 'true'" do
    # Set config to true but env var to false
    Rails.application.config.memorial = { features: { commenting_enabled: true } }
    ENV['MEMORIAL_COMMENTING_ENABLED'] = 'false'
    
    assert_not commenting_enabled?
    
    # Clean up
    ENV.delete('MEMORIAL_COMMENTING_ENABLED')
  end
end