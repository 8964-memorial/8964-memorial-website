class PagesController < ApplicationController
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
end
