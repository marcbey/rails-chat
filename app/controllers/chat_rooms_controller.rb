class ChatRoomsController < ApplicationController
  before_action :load_rooms
  before_action :set_chat_room, only: :show

  def index
    @chat_room = ChatRoom.new
  end

  def show
    @chat_rooms = ChatRoom.order(created_at: :desc)
    @chat_room_form = ChatRoom.new
    @chat_message = @chat_room.chat_messages.build
    @chat_messages = @chat_room.chat_messages.includes(:user).order(:created_at)
    @chat_room_membership = @chat_room.membership_for(current_user)
  end

  def new
    redirect_to chat_rooms_path
  end

  def create
    @chat_room = ChatRoom.new(chat_room_params)

    respond_to do |format|
      if @chat_room.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new_chat_room",
            partial: "chat_rooms/form",
            locals: { chat_room: ChatRoom.new }
          )
        end
        format.html { redirect_to chat_room_path(@chat_room), notice: "Room created." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new_chat_room",
            partial: "chat_rooms/form",
            locals: { chat_room: @chat_room }
          ), status: :unprocessable_entity
        end
        format.html do
          @chat_rooms = ChatRoom.order(created_at: :desc)
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def chat_room_params
    params.require(:chat_room).permit(:name)
  end

  def load_rooms
    @chat_rooms = ChatRoom.order(created_at: :desc)
  end

  def set_chat_room
    @chat_room = ChatRoom.find_by!(slug: params[:id])
  end
end
