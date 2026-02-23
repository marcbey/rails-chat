require "rails_helper"

RSpec.describe ChatMessage, type: :model do
  let(:chat_room) { ChatRoom.create!(name: "General") }
  let(:user) { User.create!(username: "marc", password: "password123!", password_confirmation: "password123!") }

  it "requires a user" do
    message = chat_room.chat_messages.build(body: "Hello")

    expect(message).not_to be_valid
    expect(message.errors[:user]).to be_present
  end

  it "requires body" do
    message = chat_room.chat_messages.build(user: user)

    expect(message).not_to be_valid
    expect(message.errors[:body]).to be_present
  end

  it "is valid with user and body" do
    message = chat_room.chat_messages.build(user: user, body: "Hello world")

    expect(message).to be_valid
  end
end
