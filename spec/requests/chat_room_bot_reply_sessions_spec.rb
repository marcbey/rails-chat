require "rails_helper"

RSpec.describe "ChatRoomBotReplySessions", type: :request do
  let(:password) { "password123!" }
  let(:user) { User.create!(username: "marc", password: password, password_confirmation: password) }
  let(:chat_room) { ChatRoom.create!(name: "General") }

  describe "POST /chat_rooms/:chat_room_id/bot_reply_session" do
    it "returns forbidden when bot is disabled" do
      sign_in_as(user, password: password)
      chat_room.membership_for(user).update!(bot_enabled: false)

      post chat_room_bot_reply_session_path(chat_room), headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
