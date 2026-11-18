require "net/http"
require "uri"

# All talking to the physical door controller goes through here, so the network
# timeouts live in one place. The board is a small Arduino on the LAN; a slow or
# unplugged board must fail fast (DoorBoard::Unreachable) instead of tying up a
# web worker indefinitely. Callers rescue Unreachable and report a clean failure.
module DoorBoard
  OPEN_TIMEOUT = 5  # seconds to connect to the board
  READ_TIMEOUT = 10 # seconds to wait for its reply

  # Transport-level failures that all mean "the board did not answer in time".
  # SystemCallError covers the Errno::* family (connection refused, host
  # unreachable, timed out).
  TRANSPORT_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Timeout::Error,
    SocketError, SystemCallError, EOFError, IOError
  ].freeze

  class Unreachable < StandardError; end

  module_function

  # Door jobs are the scheduled work only one server may do: the door log
  # import every 6 minutes (it clears the board's log) and the after-hours
  # lock. Production leaves DOOR_JOBS unset. A staging copy runs with
  # DOOR_JOBS=off so it never repeats them; members' own door actions there
  # still work.
  def jobs_enabled?
    ENV["DOOR_JOBS"].to_s.strip.downcase != "off"
  end

  JOBS_OFF_MESSAGE = "Door jobs are off on this server (DOOR_JOBS=off).".freeze

  # GET door_access_url + "?" + query and return the response body as a String.
  # The query is passed through untouched: the firmware parses a raw, fixed-width
  # query string and runs one command per request, so callers are responsible for
  # supplying safe values (see Card's card_number hex validation). Raises
  # DoorBoard::Unreachable on any transport error. One attempt only: a slow board
  # must not be retried (max_retries = 0), so the worst case is READ_TIMEOUT.
  def get(query)
    uri = URI("#{APP_CONFIG['door_access_url']}?#{query}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.max_retries = 0
    response = http.start { |h| h.request(Net::HTTP::Get.new(uri.request_uri)) }
    response.body.to_s
  rescue *TRANSPORT_ERRORS => e
    Rails.logger.warn("DoorBoard unreachable: #{e.class}: #{e.message}")
    raise Unreachable, e.message
  end
end
