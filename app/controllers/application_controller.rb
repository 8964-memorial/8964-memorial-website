class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  protect_from_forgery with: :exception
  
  # Add basic security headers
  before_action :set_security_headers
  
  private
  
  def set_security_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    # The legacy XSS auditor is deprecated and can introduce its own issues;
    # modern browsers rely on CSP instead, so explicitly disable it.
    response.headers['X-XSS-Protection'] = '0'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end
end
