class PagesController < ApplicationController
  before_action :check_commenting_enabled, only: [:say, :create]

  def index
    @messages = Message.all.shuffle
  end

  def say
    @message = Message.new
  end

  def create
    # Honeypot — real users never see/fill this field; silently pretend success
    # so the bot gets no signal, but persist nothing. Also feeds the Fail2Ban
    # counter so a flooding bot ends up IP-blocked.
    if params[:email_confirmation].present?
      log_security_event(reason: :honeypot)
      flag_security_offender(:honeypot)
      redirect_to root_path and return
    end

    # Attack-pattern detection — same silent-drop posture as the honeypot. The
    # response is indistinguishable from a successful submission so we don't
    # tell the attacker which payloads we filter.
    if (signature = detect_attack_signature)
      log_security_event(reason: signature[:pattern], field: signature[:field], value: signature[:value])
      flag_security_offender(signature[:pattern])
      redirect_to root_path and return
    end

    @message = Message.new(message_params)

    if @message.save
      redirect_to root_path
    else
      render :say
    end
  end

  private

  def message_params
    params.require(:message).permit(:name, :content)
  end

  def check_commenting_enabled
    unless helpers.commenting_enabled?
      redirect_to root_path, alert: '留言功能目前已關閉'
    end
  end

  def detect_attack_signature
    message = params[:message]
    # Only scan well-formed nested params; a malformed shape (string/array) is
    # left to message_params below rather than crashing the scan on #dig.
    return nil unless message.is_a?(ActionController::Parameters)
    [:name, :content].each do |field|
      value = message[field].to_s
      next if value.empty?
      pattern = SecurityFilter.attack_signature(value)
      return { field: field, pattern: pattern, value: value } if pattern
    end
    nil
  end

  def log_security_event(reason:, field: nil, value: nil)
    parts = [
      "[security][attack-attempt]",
      "reason=#{reason}",
      "ip=#{client_ip}",
      "ua=#{request.user_agent.to_s.inspect}"
    ]
    parts << "field=#{field}" if field
    parts << "value=#{value.inspect}" if value
    Rails.logger.warn(parts.join(" "))
  end

  def flag_security_offender(reason)
    # Rack::Attack.enabled is false in test env (see rack_attack initializer);
    # skip Fail2Ban there so tests don't bleed counts across runs via FileStore.
    return unless Rack::Attack.enabled
    ip = client_ip
    key = "attack:#{ip}"
    # filter() always returns truthy here (the block does), so compare the ban
    # state before/after to log the ban exactly once, at the transition.
    was_banned = Rack::Attack::Fail2Ban.banned?(key)
    Rack::Attack::Fail2Ban.filter(key, maxretry: 3, findtime: 1.hour, bantime: 24.hours) { true }
    if Rack::Attack::Fail2Ban.banned?(key) && !was_banned
      Rails.logger.warn("[security][ip-banned] ip=#{ip} reason=#{reason}")
    end
  end

  def client_ip
    request.headers['CF-Connecting-IP'] || request.remote_ip
  end
end
