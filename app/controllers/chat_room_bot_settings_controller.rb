class ChatRoomBotSettingsController < ApplicationController
  before_action :set_chat_room

  def update
    membership = @chat_room.membership_for(current_user)
    membership.update!(bot_enabled: ActiveModel::Type::Boolean.new.cast(params[:bot_enabled]))

    redirect_to chat_room_path(@chat_room), notice: "Bot setting updated."
  end

  private

  def set_chat_room
    @chat_room = ChatRoom.find_by!(slug: params[:chat_room_id])
  end
end
