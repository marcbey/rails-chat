require "rails_helper"

RSpec.describe "ChatRoomBotSettings", type: :request do
  let(:password) { "password123!" }
  let(:user) { User.create!(username: "marc", password: password, password_confirmation: password) }
  let(:chat_room) { ChatRoom.create!(name: "General") }

  describe "PATCH /chat_rooms/:chat_room_id/bot_setting" do
    it "enables bot for the signed-in user in that room" do
      sign_in_as(user, password: password)

      expect {
        patch chat_room_bot_setting_path(chat_room), params: { bot_enabled: true }
      }.to change(ChatRoomMembership, :count).by(1)

      membership = ChatRoomMembership.find_by!(user: user, chat_room: chat_room)
      expect(membership.bot_enabled).to be(true)
      expect(response).to redirect_to(chat_room_path(chat_room))
    end
  end
end
