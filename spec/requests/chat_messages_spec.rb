require "rails_helper"

RSpec.describe "ChatMessages", type: :request do
  describe "POST /chat_rooms/:chat_room_id/chat_messages" do
    it "creates a message and redirects" do
      room = ChatRoom.create!(name: "General")

      expect {
        post chat_room_chat_messages_path(room), params: {
          chat_message: {
            author_name: "Marc",
            body: "Realtime test"
          }
        }
      }.to change(ChatMessage, :count).by(1)

      expect(response).to redirect_to(chat_room_path(room))
    end
  end
end
