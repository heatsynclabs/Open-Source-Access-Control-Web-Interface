require 'net/http'
require 'uri'
require 'json'

# Client for the external door-api service (https://github.com/heatsynclabs/door-api).
# Used instead of talking to the board directly when APP_CONFIG['door_backend'] is
# "door_api". Stateless; one instance per call is fine. Mirrors DoorBoard's
# discipline: explicit timeouts, no retries (a door command must not silently
# repeat), and a single Unreachable error on any transport failure.
class DoorApiClient
  class Error < StandardError; end
  class Unreachable < Error; end

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15 # a cards/sync against the legacy board can take a few seconds

  # True when the members app should route door/card operations through door-api.
  def self.enabled?
    APP_CONFIG['door_backend'].to_s == 'door_api'
  end

  def initialize(controller: APP_CONFIG['door_controller'],
                 base_url: APP_CONFIG['door_api_url'],
                 api_key: APP_CONFIG['door_api_key'])
    @controller = controller
    @base = base_url.to_s.sub(%r{/+\z}, '')
    @api_key = api_key.to_s
  end

  # ---- doors ----

  # action is "unlock", "lock" or "open". Sends an empty JSON body so the request
  # carries a Content-Type door-api's parser accepts (a bodyless POST otherwise
  # gets Net::HTTP's default form content-type).
  def door(door_number, action)
    post("/v1/controllers/#{@controller}/doors/#{door_number}/#{action}", {})
  end

  # ---- status ----

  # Returns the shape DoorLog.show_status expects:
  #   { :unlocked => bool, :door_1_locked => bool, :door_2_locked => bool, ... }
  def status
    data = get("/v1/controllers/#{@controller}/status")
    doors = data['doors'] || []
    result = { :unlocked => doors.any? { |d| d['locked'] == false } }
    doors.each { |d| result["door_#{d['door']}_locked".to_sym] = (d['locked'] != false) }
    result
  end

  # ---- cards ----

  # Create or update a card. number is decimal; doors is an array like [1, 2]
  # (empty = present but no access). Returns true on success, false on failure.
  def put_card(number:, doors:, from: nil, to: nil)
    body = { :doors => doors }
    body[:from] = from if from
    body[:to] = to if to
    put("/v1/controllers/#{@controller}/cards/#{number}", body)
    true
  rescue Error
    false
  end

  def delete_card(number)
    delete("/v1/controllers/#{@controller}/cards/#{number}")
    true
  rescue Error
    false
  end

  # Reconcile the board to a set of cards: [{ card: <decimal>, doors: [..] }, ...].
  # Returns the door-api summary { "added"=>, "updated"=>, "removed"=>, "failed"=>[] }.
  def sync(cards:, prune: false)
    post("/v1/controllers/#{@controller}/cards/sync", { :cards => cards, :prune => prune })
  end

  private

  def get(path)
    request(Net::HTTP::Get.new(uri(path)))
  end

  def post(path, body = nil)
    request(with_body(Net::HTTP::Post.new(uri(path)), body))
  end

  def put(path, body = nil)
    request(with_body(Net::HTTP::Put.new(uri(path)), body))
  end

  def delete(path)
    request(Net::HTTP::Delete.new(uri(path)))
  end

  def uri(path)
    URI("#{@base}#{path}")
  end

  def with_body(req, body)
    if body
      req['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    req
  end

  def request(req)
    req['Authorization'] = "Bearer #{@api_key}" unless @api_key.empty?
    u = req.uri
    http = Net::HTTP.new(u.host, u.port)
    http.use_ssl = (u.scheme == 'https')
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.max_retries = 0
    res = http.start { |h| h.request(req) }
    raise Error, "door-api #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    res.body.to_s.empty? ? {} : JSON.parse(res.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, SystemCallError, EOFError, IOError => e
    raise Unreachable, "door-api unreachable: #{e.message}"
  end
end
