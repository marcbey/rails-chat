require "rails_helper"

RSpec.describe "ChatMessages", type: :request do
  let(:user_password) { "password123!" }
  let(:user) { User.create!(username: "marc", email_address: "marc@example.com", password: user_password, password_confirmation: user_password) }

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

    it "creates chat room membership for sender if missing" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "General")

      expect(ChatRoomMembership.exists?(chat_room: room, user: user)).to be(false)

      post chat_room_chat_messages_path(room), params: {
        chat_message: {
          body: "Membership test"
        }
      }

      expect(ChatRoomMembership.exists?(chat_room: room, user: user)).to be(true)
      expect(response).to redirect_to(chat_room_path(room))
    end

    it "rejects messages longer than 2000 chars" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "General")

      expect {
        post chat_room_chat_messages_path(room), params: {
          chat_message: {
            body: "x" * 2001
          }
        }
      }.not_to change(ChatMessage, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is too long")
    end
  end
end
