require "rails_helper"

RSpec.describe "ChatRooms", type: :request do
  describe "GET /" do
    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /chat_rooms" do
    it "creates a room and redirects for HTML" do
      expect {
        post chat_rooms_path, params: { chat_room: { name: "General" } }
      }.to change(ChatRoom, :count).by(1)

      expect(response).to redirect_to(chat_room_path(ChatRoom.last))
    end
  end

  describe "GET /chat_rooms/:id" do
    it "renders a room" do
      room = ChatRoom.create!(name: "Engineering")

      get chat_room_path(room)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Engineering")
    end
  end
end
