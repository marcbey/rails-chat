class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  throttle("chat_messages/create/ip", limit: 60, period: 1.minute) do |req|
    next unless req.post?
    next unless req.path.match?(%r{\A/chat_rooms/[^/]+/chat_messages\z})

    req.ip
  end

  throttle("chat_rooms/create/ip", limit: 20, period: 1.minute) do |req|
    next unless req.post?
    next unless req.path == "/chat_rooms"

    req.ip
  end

  self.throttled_responder = lambda do |_request|
    headers = {
      "Content-Type" => "text/plain",
      "Retry-After" => "60"
    }

    [ 429, headers, [ "Rate limit exceeded. Please try again later." ] ]
  end
end
