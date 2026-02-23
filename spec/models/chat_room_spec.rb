require "rails_helper"

RSpec.describe ChatRoom, type: :model do
  it "validates presence and uniqueness of name" do
    ChatRoom.create!(name: "General")

    room = ChatRoom.new(name: "General")

    expect(room).not_to be_valid
    expect(room.errors[:name]).to be_present
  end

  it "generates a slug from name" do
    room = ChatRoom.create!(name: "Engineering Team")

    expect(room.slug).to eq("engineering-team")
  end

  it "ensures slug uniqueness" do
    ChatRoom.create!(name: "Product")
    room = ChatRoom.create!(name: "Product  ")

    expect(room.slug).to start_with("product")
    expect(ChatRoom.distinct.count(:slug)).to eq(ChatRoom.count)
  end

  it "detects direct-message rooms by participant count" do
    room = ChatRoom.create!(name: "Direct")
    user_1 = User.create!(username: "user1", email_address: "u1@example.com", password: "password123!", password_confirmation: "password123!")
    user_2 = User.create!(username: "user2", email_address: "u2@example.com", password: "password123!", password_confirmation: "password123!")

    room.membership_for(user_1)
    expect(room.direct_message_room?).to be(false)

    room.membership_for(user_2)
    expect(room.direct_message_room?).to be(true)
  end
end
