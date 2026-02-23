require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    it "renders sign up page" do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create account")
    end
  end

  describe "POST /registration" do
    it "creates a user and starts a session" do
      expect {
        post registration_path, params: {
          user: {
            username: "new_user",
            email_address: "new_user@example.com",
            password: "password123!",
            password_confirmation: "password123!"
          }
        }
      }.to change(User, :count).by(1).and change(Session, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(User.last.username).to eq("new_user")
      expect(User.last.email_address).to eq("new_user@example.com")
    end
  end
end
