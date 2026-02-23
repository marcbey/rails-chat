class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :user

  validates :body, presence: true, length: { maximum: 2000 }

  after_create_commit :broadcast_new_message

  private

  def broadcast_new_message
    broadcast_append_later_to(
      [ chat_room, "messages" ],
      target: chat_room.messages_dom_id,
      partial: "chat_messages/chat_message",
      locals: { chat_message: self }
    )
  end
end
