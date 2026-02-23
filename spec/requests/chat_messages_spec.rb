require "rails_helper"

RSpec.describe "ChatMessages", type: :request do
  let(:user_password) { "password123!" }
  let(:user) { User.create!(username: "marc", password: user_password, password_confirmation: user_password) }

  describe "POST /chat_rooms/:chat_room_id/chat_messages" do
    it "creates a message and redirects" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "General")

      expect {
        post chat_room_chat_messages_path(room), params: {
          chat_message: {
            body: "Realtime test"
          }
        }
      }.to change(ChatMessage, :count).by(1)

      expect(response).to redirect_to(chat_room_path(room))
      expect(ChatMessage.last.user).to eq(user)
    end
  end
end
