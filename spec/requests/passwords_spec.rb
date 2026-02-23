require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let(:user) do
    User.create!(
      username: "marc",
      email_address: "marc@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
  end

  describe "POST /passwords" do
    it "sends reset instructions for existing user" do
      expect {
        post passwords_path, params: { email_address: user.email_address }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PATCH /passwords/:token" do
    it "resets password via token" do
      token = user.password_reset_token
      user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

      expect {
        patch password_path(token), params: {
          user: {
            password: "newpassword123!",
            password_confirmation: "newpassword123!"
          }
        }
      }.to change { user.sessions.count }.from(1).to(0)

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("newpassword123!")).to be_present
    end
  end
end
