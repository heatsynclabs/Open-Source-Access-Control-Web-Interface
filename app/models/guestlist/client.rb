require "net/http"

module Guestlist
  # Reads guestlist.co's public JSON pages.
  class Client
    HOST = "https://guestlist.co"
    class Error < StandardError; end

    # The profile's published events that have not started yet.
    def upcoming_event_ids
      get("/api/events?username=#{USERNAME}").fetch("events").filter_map { |event| event["id"] if event["profile_id"] == PROFILE_ID }
    end

    # The event's JSON, or nil when guestlist no longer has it.
    def event(id)
      get("/api/events/#{Integer(id)}")&.fetch("event")
    end

    def ticket_types(id)
      get("/api/ticket_types?event_id=#{Integer(id)}")&.fetch("ticket_types") || []
    end

    private

    def get(path)
      uri = URI(HOST + path)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.get(uri.request_uri, "Accept" => "application/json", "User-Agent" => "HeatSyncLabsMembers/1.0 (+https://members.heatsynclabs.org)")
      end
      return nil if response.is_a?(Net::HTTPNotFound)
      raise Error, "#{path} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
      raise Error, "#{path}: #{error.class}: #{error.message}"
    end
  end
end
