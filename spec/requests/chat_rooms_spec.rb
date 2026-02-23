require "rails_helper"

RSpec.describe "ChatRooms", type: :request do
  let(:user_password) { "password123!" }
  let(:user) { User.create!(username: "marc", email_address: "marc@example.com", password: user_password, password_confirmation: user_password) }

  def create_user(username)
    User.create!(
      username: username,
      email_address: "#{username}@example.com",
      password: user_password,
      password_confirmation: user_password
    )
  end

  describe "GET /" do
    it "redirects to sign in when unauthenticated" do
      get root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "renders successfully for authenticated users" do
      sign_in_as(user, password: user_password)

      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chat_rooms" do
    it "creates a room and redirects for HTML" do
      sign_in_as(user, password: user_password)

      expect {
        post chat_rooms_path, params: { chat_room: { name: "General" } }
      }.to change(ChatRoom, :count).by(1)

      expect(response).to redirect_to(chat_room_path(ChatRoom.last))
    end
  end

  describe "GET /chat_rooms/:id" do
    it "renders a room" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "Engineering")

      get chat_room_path(room)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Engineering")
    end

    it "disables mention requirement for bot replies in two-user rooms" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "Direct")
      room.membership_for(user)
      room.membership_for(create_user("alice"))

      get chat_room_path(room)

      expect(response.body).to include('data-chat-bot-require-mention-value="false"')
    end

    it "keeps mention requirement for bot replies in rooms with more than two users" do
      sign_in_as(user, password: user_password)
      room = ChatRoom.create!(name: "Team")
      room.membership_for(user)
      room.membership_for(create_user("alice"))
      room.membership_for(create_user("bob"))

      get chat_room_path(room)

      expect(response.body).to include('data-chat-bot-require-mention-value="true"')
    end
  end
end
