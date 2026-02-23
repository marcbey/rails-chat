require 'rails_helper'

RSpec.describe User, type: :model do
  it "normalizes username to lowercase" do
    user = User.create!(
      username: "Marc_Test",
      email_address: "Marc_Test@Example.COM",
      password: "password123!",
      password_confirmation: "password123!"
    )

    expect(user.username).to eq("marc_test")
    expect(user.email_address).to eq("marc_test@example.com")
  end

  it "validates username format" do
    user = User.new(
      username: "Invalid Name",
      email_address: "invalid@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )

    expect(user).not_to be_valid
    expect(user.errors[:username]).to be_present
  end
end
