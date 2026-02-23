require "rails_helper"

RSpec.describe ChatMessage, type: :model do
  let(:chat_room) { ChatRoom.create!(name: "General") }
  let(:user) do
    User.create!(
      username: "marc",
      email_address: "marc@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
  end

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

  it "limits body length to 2000 characters" do
    message = chat_room.chat_messages.build(user: user, body: "x" * 2001)

    expect(message).not_to be_valid
    expect(message.errors[:body]).to be_present
  end
end
