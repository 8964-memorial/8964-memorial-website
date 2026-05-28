# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    # Scripts are served from this app only (turbo/stimulus via importmap, all
    # compiled from self). Do NOT add :https here — it would allow scripts from
    # any HTTPS origin and defeat CSP's XSS protection. Inline importmap scripts
    # are permitted via the per-request nonce below.
    policy.script_src  :self
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https
    policy.frame_ancestors :none
    # Allow Facebook for the event banner
    policy.frame_src   'https://www.facebook.com'
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate a fresh random nonce per request. (Using the session id would make
  # the nonce predictable and constant for the whole session.)
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
