class PagesController < ApplicationController
  before_action :check_commenting_enabled, only: [:say, :create]
  
  def index
    @messages = Message.all.shuffle
  end

  def say
    @message = Message.new
  end

  def create
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
    unless commenting_enabled?
      redirect_to root_path, alert: '留言功能目前已關閉'
    end
  end

  def commenting_enabled?
    # Check environment variable first, then config
    return ENV['MEMORIAL_COMMENTING_ENABLED'] == 'true' if ENV['MEMORIAL_COMMENTING_ENABLED'].present?
    Rails.application.config.memorial[:features][:commenting_enabled]
  end
end
