class ChatMessagesController < ApplicationController
  before_action :set_chat_room

  def create
    @chat_message = @chat_room.chat_messages.build(chat_message_params)

    respond_to do |format|
      if @chat_message.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            message_form_dom_id,
            partial: "chat_messages/form",
            locals: { chat_room: @chat_room, chat_message: @chat_room.chat_messages.build }
          )
        end
        format.html { redirect_to chat_room_path(@chat_room), notice: "Message sent." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            message_form_dom_id,
            partial: "chat_messages/form",
            locals: { chat_room: @chat_room, chat_message: @chat_message }
          ), status: :unprocessable_entity
        end
        format.html do
          @chat_rooms = ChatRoom.order(created_at: :desc)
          @chat_messages = @chat_room.chat_messages.order(:created_at)
          @chat_room_form = ChatRoom.new
          render "chat_rooms/show", status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_chat_room
    @chat_room = ChatRoom.find_by!(slug: params[:chat_room_id])
  end

  def chat_message_params
    params.require(:chat_message).permit(:author_name, :body)
  end

  def message_form_dom_id
    "#{@chat_room.messages_dom_id}_form"
  end
end
