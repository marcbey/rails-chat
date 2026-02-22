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
end
