require 'net/http'
require 'uri'
require 'json'

# Talks to the LED marquee in the lab window (https://github.com/heatsynclabs/marquee)
# over the lab network. The panel is a small ESP8266 serving plain HTTP, so every
# call has short timeouts and no retries, and any transport failure becomes
# Marquee::Client::Unreachable. Pages catch that and say the sign is not
# answering; nothing here may raise anything else into a request.
#
# Stateless; one instance per call is fine.
module Marquee
  class Client
    class Error < StandardError; end
    class Unreachable < Error; end

    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 4
    # A hostname or IPv4 address, optionally with a port. Nothing else reaches
    # Net::HTTP, so a bad setting cannot turn into a request somewhere odd.
    HOST_FORMAT = /\A[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?(:\d{1,5})?\z/i

    attr_reader :host

    def initialize(host: Setting.marquee_host)
      @host = host.to_s.strip.sub(%r{\Ahttps?://}i, '').sub(%r{/+\z}, '')
    end

    def configured?
      @host.match?(HOST_FORMAT)
    end

    # The panel's /api/state: what it shows, its health, its rotation.
    def state
      get('/api/state')
    end

    # The saved idle rotation: { "ms", "items" => [...], "open" => {...} }.
    def rotation
      get('/api/rotate')
    end

    def set_rotation(doc)
      post('/api/rotate', doc)
    end

    # One command object, as docs/api.md in the marquee repository describes.
    def command(cmd)
      post('/api/cmd', cmd)
    end

    def poll_status
      post('/api/status/poll', {})
    end

    def reboot
      post('/api/reboot', {})
    end

    private

    def get(path)
      request(Net::HTTP::Get.new(uri(path)))
    end

    def post(path, body)
      req = Net::HTTP::Post.new(uri(path))
      req['Content-Type'] = 'application/json'
      req.body = body.to_json
      request(req)
    end

    def uri(path)
      raise Unreachable, "no valid marquee address is set" unless configured?
      URI("http://#{@host}#{path}")
    end

    def request(req)
      http = Net::HTTP.new(req.uri.host, req.uri.port)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = READ_TIMEOUT
      http.max_retries = 0
      res = http.start { |h| h.request(req) }
      data = parse(res.body)
      unless res.is_a?(Net::HTTPSuccess)
        raise Error, (data.is_a?(Hash) && data['error'].presence) || "the sign answered #{res.code}"
      end
      data
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error, SocketError,
           SystemCallError, EOFError, IOError, OpenSSL::SSL::SSLError => e
      raise Unreachable, "the sign is not answering (#{e.class.name.demodulize})"
    end

    def parse(body)
      text = body.to_s
      return {} if text.empty?
      JSON.parse(text)
    rescue JSON::ParserError
      raise Error, "the sign sent something that is not JSON"
    end
  end
end
