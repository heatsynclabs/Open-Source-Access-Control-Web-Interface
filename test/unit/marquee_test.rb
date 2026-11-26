require 'test_helper'
require 'socket'

# The window sign: what may be sent (Marquee), the rotation form
# (Marquee::Rotation) and the client against a tiny in-process HTTP server
# standing in for the sign, so no hardware is needed.
class MarqueeTest < ActiveSupport::TestCase
  # ---- messages ----

  test 'messages keep printable ASCII, straighten quotes and are cut to length' do
    assert_equal "WE'RE OPEN - come in", Marquee.clean_text("WE’RE  OPEN — come in\n")
    assert_equal "caf", Marquee.clean_text("café")
    assert_equal 100, Marquee.clean_text("x" * 500).length
    assert_equal "", Marquee.clean_text("\u{1F916}  ")
    assert_equal "", Marquee.clean_text(nil)
  end

  test 'a message command only uses offered colours and repeat counts' do
    cmd = Marquee.message_command(text: " hi ", color: "Pink", repeat: "3")
    assert_equal({ "text" => "hi", "color" => "#ff5a9a", "repeat" => 3 }, cmd)

    odd = Marquee.message_command(text: "hi", color: "<script>", repeat: "9999")
    assert_equal "#ff9f43", odd["color"]
    assert_equal 1, odd["repeat"]

    assert_nil Marquee.message_command(text: "   ", color: "Pink", repeat: 1)
  end

  test 'frames keep words and the until token, nothing else' do
    assert_equal "OPEN|COME IN {bot}", Marquee.clean_frames(" OPEN | COME  IN {bot} || \u00e9 ")
    assert_operator Marquee.clean_frames((["WE'RE OPEN COME IN"] * 12).join("|")).length, :<=, 120
    assert_equal Marquee::FRAME_MAX, Marquee.clean_frames((["A"] * 40).join("|")).split("|").size
  end

  test 'showing turns the sign state into words' do
    assert_equal "the robot", Marquee.showing({ "kind" => "anim", "arg" => "robot" })
    assert_equal "OPEN / OPEN HOURS, COME IN", Marquee.showing({ "kind" => "cards", "arg" => "OPEN|OPEN HOURS {bot} COME IN" })
    assert_equal "“hi”", Marquee.showing({ "kind" => "text", "arg" => "hi" })
    assert_equal "unknown", Marquee.showing(nil)
  end

  # ---- rotation ----

  PANEL_ROTATION = {
    "ms" => 15000,
    "items" => [{ "anim" => "clock" }, { "text" => "HEATSYNC LABS", "color" => "#ff9f43" },
                { "anim" => "plasma" }, { "anim" => "robot", "hold" => 16800 }],
    "open" => { "cards" => "OPEN|HOURS|{until}", "color" => "#33ff66" },
  }.freeze

  test 'the rotation reads from the sign and writes the same thing back' do
    rotation = Marquee::Rotation.from_panel(PANEL_ROTATION)
    assert rotation.clock
    assert rotation.robot
    assert rotation.open_enabled
    assert_equal "OPEN|HOURS|{until}", rotation.open_frames
    assert_equal 15, rotation.seconds
    assert_equal({ "text" => "HEATSYNC LABS", "color" => "Orange" }, rotation.texts.first)
    assert_equal ["plasma"], rotation.extra_labels

    doc = rotation.to_panel
    assert_equal 15000, doc["ms"]
    assert_equal [{ "anim" => "clock" }, { "text" => "HEATSYNC LABS", "color" => "#ff9f43" },
                  { "anim" => "robot", "hold" => 16800 }, { "anim" => "plasma" }], doc["items"]
    assert_equal({ "cards" => "OPEN|HOURS|{until}", "color" => "#33ff66" }, doc["open"])
  end

  test 'the rotation form keeps entries it does not edit and refuses an empty or oversized mix' do
    params = ActionController::Parameters.new(
      "clock" => "0", "robot" => "1", "open_enabled" => "0", "open_frames" => "OPEN", "seconds" => "20",
      "texts" => { "0" => { "text" => "HELLO", "color" => "Cyan" }, "1" => { "text" => "", "color" => "Pink" } })
    rotation = Marquee::Rotation.from_params(params, extras: [{ "anim" => "fire" }])
    assert rotation.valid?
    doc = rotation.to_panel
    assert_equal [{ "text" => "HELLO", "color" => "#20e0ff" }, { "anim" => "robot", "hold" => 16800 }, { "anim" => "fire" }],
                 doc["items"]
    assert_equal false, doc["open"]
    assert_equal 20000, doc["ms"]

    empty = Marquee::Rotation.new(clock: false, robot: false)
    refute empty.valid?

    crowded = Marquee::Rotation.new(texts: [{ "text" => "A" }, { "text" => "B" }, { "text" => "C" }],
                                    extras: [{ "anim" => "fire" }, { "anim" => "rain" }])
    refute crowded.valid?, "clock + 3 texts + robot + 2 extras is 7"

    slow = Marquee::Rotation.new(seconds: 1000)
    refute slow.valid?
  end

  test 'a rotation from a sign that sent nonsense still renders a usable form' do
    rotation = Marquee::Rotation.from_panel("not a hash")
    refute rotation.clock
    assert_equal Marquee::Rotation::TEXT_LINES, rotation.texts.size
    rotation = Marquee::Rotation.from_panel({ "items" => ["x", nil, 3], "ms" => "abc" })
    assert_equal 5, rotation.seconds
  end

  # ---- client ----

  def start_sign
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def teardown
    @server&.close rescue nil
    @thread&.kill rescue nil
  end

  def serve
    loop do
      sock = @server.accept
      line = sock.gets.to_s
      headers = {}
      while (h = sock.gets) && h != "\r\n"
        k, v = h.split(':', 2)
        headers[k.downcase] = v.to_s.strip
      end
      body = headers['content-length'] ? sock.read(headers['content-length'].to_i) : ''
      method, path = line.split(' ')
      @requests << { method: method, path: path, body: body }
      code, reply = @reply.call(method, path)
      sock.write "HTTP/1.1 #{code} X\r\nContent-Type: application/json\r\nContent-Length: #{reply.bytesize}\r\nConnection: close\r\n\r\n#{reply}"
      sock.close
    end
  rescue IOError, Errno::EBADF
  end

  test 'the client sends commands as JSON and reads the reply' do
    start_sign
    @reply = ->(_m, path) { [200, path == '/api/state' ? '{"fw":"1.1.1"}' : '{"ok":true}'] }
    client = Marquee::Client.new(host: "127.0.0.1:#{@port}")
    assert_equal({ "fw" => "1.1.1" }, client.state)
    client.command({ "text" => "hi" })
    assert_equal ['GET /api/state', 'POST /api/cmd'], @requests.map { |r| "#{r[:method]} #{r[:path]}" }
    assert_equal({ "text" => "hi" }, JSON.parse(@requests.last[:body]))
  end

  test 'the sign refusing a command is an Error with its reason' do
    start_sign
    @reply = ->(_m, _p) { [400, '{"ok":false,"error":"queue full"}'] }
    error = assert_raises(Marquee::Client::Error) { Marquee::Client.new(host: "127.0.0.1:#{@port}").command({}) }
    assert_equal "queue full", error.message
    refute_kind_of Marquee::Client::Unreachable, error
  end

  test 'a reply that is not JSON is an Error, not a crash' do
    start_sign
    @reply = ->(_m, _p) { [200, '<html>'] }
    assert_raises(Marquee::Client::Error) { Marquee::Client.new(host: "127.0.0.1:#{@port}").state }
  end

  test 'nothing listening is Unreachable' do
    port = TCPServer.open('127.0.0.1', 0) { |s| s.addr[1] } # free, then closed
    assert_raises(Marquee::Client::Unreachable) { Marquee::Client.new(host: "127.0.0.1:#{port}").state }
  end

  test 'a bad address never reaches the network' do
    ["", "http://", "evil.com/../x", "a b", "host:99999999", "user@host"].each do |host|
      client = Marquee::Client.new(host: host)
      refute client.configured?, host
      assert_raises(Marquee::Client::Unreachable) { client.state }
    end
    assert Marquee::Client.new(host: "http://172.22.110.185/").configured?
    assert Marquee::Client.new(host: "marquee.lan:8080").configured?
  end
end
