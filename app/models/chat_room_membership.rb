class ChatRoomMembership < ApplicationRecord
  belongs_to :user
  belongs_to :chat_room

  validates :user_id, uniqueness: { scope: :chat_room_id }
  validates :bot_enabled, inclusion: { in: [ true, false ] }
end
