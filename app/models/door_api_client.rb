require 'net/http'
require 'uri'
require 'json'

# Client for the door-api service (https://github.com/heatsynclabs/door-api).
# Used instead of talking to the board directly when APP_CONFIG['door_backend'] is
# "door_api". door-api sends the board exactly the query the direct path sends
# (?o1, ?u=1, ?l, ?m010&p001&t..., ?z, ?y), one request at a time, so the board
# behaves the same; members never needs the board password on this path.
#
# Stateless; one instance per call is fine. Explicit timeouts, no retries (a door
# command must not silently repeat), and Unreachable on any transport failure.
class DoorApiClient
  class Error < StandardError
    attr_reader :code

    def initialize(message, code = nil)
      super(message)
      @code = code
    end
  end
  class Unreachable < Error; end

  OPEN_TIMEOUT = 5
  # door-api starts a door action within 3 s or refuses it (busy), then allows the
  # board 10 s.
  READ_TIMEOUT = 15
  # A log drain reads the board's buffer, writes it to door-api's journal and
  # clears the board, all in one step.
  DRAIN_TIMEOUT = 45

  # True when the members app should route door/card operations through door-api.
  def self.enabled?
    APP_CONFIG['door_backend'].to_s == 'door_api'
  end

  def initialize(controller: APP_CONFIG['door_controller'],
                 base_url: APP_CONFIG['door_api_url'],
                 api_key: APP_CONFIG['door_api_key'],
                 actor: nil)
    @controller = controller
    @base = base_url.to_s.sub(%r{/+\z}, '')
    @api_key = api_key.to_s
    @actor = actor
  end

  # ---- doors ----

  # One door: action is "open", "unlock" or "lock".
  def door(door_number, action)
    post("/v1/controllers/#{@controller}/doors/#{door_number}/#{action}", {})
  end

  # Every door at once, with the board's own command (?u or ?l).
  def all_doors(action)
    post("/v1/controllers/#{@controller}/doors/#{action}", {})
  end

  # "arm" (?2) or "disarm" (?1). Arming chirps for about 6 seconds.
  def alarm(action)
    post("/v1/controllers/#{@controller}/alarm/#{action}", {})
  end

  # ---- status ----

  # The board's own status fields, in the order it prints them:
  #   { "armed" => 4, "activated" => 0, "alarm_3" => 0, "alarm_2" => 0,
  #     "door_1_locked" => 1, "door_2_locked" => 1 }
  def raw_status
    data = get("/v1/controllers/#{@controller}/status")
    details = data['details']
    raise Error.new('door-api returned no board status', 'no_status') unless details.is_a?(Hash)
    details
  end

  # ---- slots (the board keys cards by slot; members uses the card id) ----

  # Write a slot. tag is the hex card number, mask the board permission (1
  # enabled, 255 disabled). door-api checks the board's read-back.
  def put_slot(slot, tag, mask)
    put("/v1/controllers/#{@controller}/slots/#{slot}", { :tag => tag.to_s, :mask => mask.to_i })
  end

  def clear_slot(slot)
    delete("/v1/controllers/#{@controller}/slots/#{slot}")
  end

  # ---- event log ----

  # Every unacknowledged drain, oldest first: [{ "drain_id", "taken_at", "raw", "cleared" }].
  # raw is the board's ?z reply from "<pre>" on, byte for byte.
  def drain
    post("/v1/controllers/#{@controller}/log/drain", {}, DRAIN_TIMEOUT)['drains'] || []
  end

  def ack(drain_id)
    post("/v1/controllers/#{@controller}/log/ack", { :drain_id => drain_id })
  end

  private

  def get(path)
    request(Net::HTTP::Get.new(uri(path)))
  end

  def post(path, body = nil, read_timeout = READ_TIMEOUT)
    request(with_body(Net::HTTP::Post.new(uri(path)), body), read_timeout)
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

  def request(req, read_timeout = READ_TIMEOUT)
    req['Authorization'] = "Bearer #{@api_key}" unless @api_key.empty?
    req['X-Door-Actor'] = @actor.to_s[0, 100] if @actor
    u = req.uri
    http = Net::HTTP.new(u.host, u.port)
    http.use_ssl = (u.scheme == 'https')
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = read_timeout
    http.max_retries = 0
    res = http.start { |h| h.request(req) }
    unless res.is_a?(Net::HTTPSuccess)
      code = (JSON.parse(res.body.to_s)['error'] rescue nil)
      raise Error.new("door-api #{res.code} #{code}", code)
    end
    res.body.to_s.empty? ? {} : JSON.parse(res.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError, SystemCallError, EOFError, IOError => e
    raise Unreachable.new("door-api unreachable: #{e.class}", 'unreachable')
  end
end
