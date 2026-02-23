require "rails_helper"

RSpec.describe "ChatRoomBotReplySessions", type: :request do
  let(:password) { "password123!" }
  let(:user) do
    User.create!(
      username: "marc",
      email_address: "marc@example.com",
      password: password,
      password_confirmation: password,
      bot_character: "Antworte freundlich."
    )
  end
  let(:chat_room) { ChatRoom.create!(name: "General") }

  describe "POST /chat_rooms/:chat_room_id/bot_reply_session" do
    it "returns forbidden when bot is disabled" do
      sign_in_as(user, password: password)
      chat_room.membership_for(user).update!(bot_enabled: false)

      post chat_room_bot_reply_session_path(chat_room), headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns a realtime client secret when bot is enabled" do
      sign_in_as(user, password: password)
      chat_room.membership_for(user).update!(bot_enabled: true)

      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("test-openai-key")
      allow(ENV).to receive(:fetch).with("OPENAI_REALTIME_MODEL", "gpt-realtime-mini").and_return("gpt-realtime-mini")

      realtime_client = instance_double(Openai::RealtimeClient, create_client_secret: "client-secret-123")
      allow(Openai::RealtimeClient).to receive(:new).with(
        api_key: "test-openai-key",
        model: "gpt-realtime-mini"
      ).and_return(realtime_client)

      post chat_room_bot_reply_session_path(chat_room), headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "client_secret" => "client-secret-123",
        "model" => "gpt-realtime-mini",
        "bot_character" => "Antworte freundlich."
      )
    end

    it "returns service unavailable when OPENAI_API_KEY is missing" do
      sign_in_as(user, password: password)
      chat_room.membership_for(user).update!(bot_enabled: true)

      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_raise(KeyError)

      post chat_room_bot_reply_session_path(chat_room), headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:service_unavailable)
      payload = JSON.parse(response.body)
      expect(payload["error"]).to eq("Missing OPENAI_API_KEY configuration")
    end

    it "returns bad gateway when OpenAI realtime initialization fails" do
      sign_in_as(user, password: password)
      chat_room.membership_for(user).update!(bot_enabled: true)

      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("test-openai-key")
      allow(ENV).to receive(:fetch).with("OPENAI_REALTIME_MODEL", "gpt-realtime-mini").and_return("gpt-realtime-mini")

      realtime_client = instance_double(Openai::RealtimeClient)
      allow(realtime_client).to receive(:create_client_secret).and_raise(Openai::RealtimeClient::Error, "upstream unavailable")
      allow(Openai::RealtimeClient).to receive(:new).and_return(realtime_client)

      post chat_room_bot_reply_session_path(chat_room), headers: { "ACCEPT" => "application/json" }

      expect(response).to have_http_status(:bad_gateway)
      payload = JSON.parse(response.body)
      expect(payload["error"]).to eq("Failed to initialize realtime bot session")
    end
  end
end
