class PagesController < ApplicationController
  before_action :check_commenting_enabled, only: [:say, :create]
  
  def index
    @messages = Message.all.shuffle
  end

  def say
    @message = Message.new
  end

  def create
    # Honeypot: real users never see/fill this field; if it's present, a bot did.
    # Silently pretend success so the bot gets no signal, but persist nothing.
    if params[:email_confirmation].present?
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
end
