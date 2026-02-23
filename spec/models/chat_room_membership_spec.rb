require 'rails_helper'

RSpec.describe ChatRoomMembership, type: :model do
  let(:user) do
    User.create!(
      username: "member_1",
      email_address: "member_1@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
  end
  let(:chat_room) { ChatRoom.create!(name: "General") }

  it "defaults bot_enabled to false" do
    membership = described_class.create!(user: user, chat_room: chat_room)

    expect(membership.bot_enabled).to be(false)
  end

  it "enforces a unique user per chat room" do
    described_class.create!(user: user, chat_room: chat_room)

    duplicate = described_class.new(user: user, chat_room: chat_room)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end
end
