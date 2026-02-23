require "json"
require "net/http"
require "uri"

module Openai
  class RealtimeClient
    Error = Class.new(StandardError)

    API_URL = URI("https://api.openai.com/v1/realtime/client_secrets")

    def initialize(api_key:, model:)
      @api_key = api_key
      @model = model
    end

    def create_client_secret
      request = Net::HTTP::Post.new(API_URL)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        {
          session: {
            type: "realtime",
            model: @model,
            output_modalities: [ "text" ]
          }
        }
      )

      response = Net::HTTP.start(API_URL.host, API_URL.port, use_ssl: true) do |http|
        http.request(request)
      end

      payload = parse_payload(response)
      secret = payload["value"] || payload.dig("client_secret", "value") || payload["client_secret"]
      raise Error, "OpenAI realtime client secret missing in response" if secret.blank?

      secret
    end

    private

    def parse_payload(response)
      parsed = JSON.parse(response.body)
      return parsed if response.is_a?(Net::HTTPSuccess)

      message = parsed["error"]&.dig("message") || "OpenAI realtime request failed (#{response.code})"
      raise Error, message
    rescue JSON::ParserError
      raise Error, "OpenAI realtime request failed with invalid JSON (#{response.code})"
    end
  end
end
