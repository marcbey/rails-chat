class ChatRoomBotReplySessionsController < ApplicationController
  before_action :set_chat_room

  def create
    membership = @chat_room.membership_for(current_user)
    return head :forbidden unless membership.bot_enabled?

    client_secret = Openai::RealtimeClient.new(
      api_key: ENV.fetch("OPENAI_API_KEY"),
      model: realtime_model
    ).create_client_secret

    render json: {
      client_secret: client_secret,
      model: realtime_model,
      bot_character: current_user.bot_character.to_s
    }
  rescue KeyError
    render json: { error: "Missing OPENAI_API_KEY configuration" }, status: :service_unavailable
  rescue Openai::RealtimeClient::Error => e
    Rails.logger.error("[openai.realtime] #{e.class}: #{e.message}")
    render json: { error: "Failed to initialize realtime bot session" }, status: :bad_gateway
  end

  private

  def set_chat_room
    @chat_room = ChatRoom.find_by!(slug: params[:chat_room_id])
  end

  def realtime_model
    ENV.fetch("OPENAI_REALTIME_MODEL", "gpt-realtime-mini")
  end
end
