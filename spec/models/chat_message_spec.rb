require "rails_helper"

RSpec.describe ChatMessage, type: :model do
  let(:chat_room) { ChatRoom.create!(name: "General") }

  it "requires author_name" do
    message = chat_room.chat_messages.build(body: "Hello")

    expect(message).not_to be_valid
    expect(message.errors[:author_name]).to be_present
  end

  it "requires body" do
    message = chat_room.chat_messages.build(author_name: "Marc")

    expect(message).not_to be_valid
    expect(message.errors[:body]).to be_present
  end

  it "is valid with author_name and body" do
    message = chat_room.chat_messages.build(author_name: "Marc", body: "Hello world")

    expect(message).to be_valid
  end
end
