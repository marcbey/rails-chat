require "rails_helper"

RSpec.describe "Account", type: :request do
  let(:password) { "password123!" }
  let(:user) { User.create!(username: "marc", email_address: "marc@example.com", password: password, password_confirmation: password) }

  describe "GET /account/edit" do
    it "renders for authenticated users" do
      sign_in_as(user, password: password)

      get edit_account_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bot character")
    end
  end

  describe "PATCH /account" do
    it "updates username and bot character" do
      sign_in_as(user, password: password)

      patch account_path, params: {
        user: {
          username: "marc_new",
          email_address: "marc_new@example.com",
          bot_character: "Antworte freundlich."
        }
      }

      expect(response).to redirect_to(edit_account_path)
      expect(user.reload.username).to eq("marc_new")
      expect(user.email_address).to eq("marc_new@example.com")
      expect(user.bot_character).to eq("Antworte freundlich.")
    end
  end
end
