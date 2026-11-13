require 'test_helper'
require 'socket'

# Exercises DoorApiClient against a tiny in-process HTTP server so no real
# door-api or hardware is needed.
class DoorApiClientTest < ActiveSupport::TestCase
  def setup
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
    @saved = APP_CONFIG.slice('door_api_url', 'door_controller', 'door_api_key', 'door_backend')
    APP_CONFIG['door_api_url'] = "http://127.0.0.1:#{@port}"
    APP_CONFIG['door_controller'] = 'front'
    APP_CONFIG['door_api_key'] = 'testkey'
  end

  def teardown
    @server.close rescue nil
    @thread.kill rescue nil
    APP_CONFIG.merge!(@saved)
  end

  test 'put_card issues an authenticated PUT with the decimal number and doors' do
    @body = '{"ok":true,"message":"written"}'
    assert_equal true, DoorApiClient.new.put_card(:number => 0x261019, :doors => [1, 2])
    req = @requests.last
    assert_equal 'PUT', req[:method]
    assert_equal "/v1/controllers/front/cards/#{0x261019}", req[:path]
    assert_equal 'Bearer testkey', req[:headers]['authorization']
    assert_equal({ 'doors' => [1, 2] }, JSON.parse(req[:body]))
  end

  test 'door posts to the right action path' do
    @body = '{"ok":true,"message":"door 1 unlock"}'
    DoorApiClient.new.door(1, 'unlock')
    assert_equal 'POST', @requests.last[:method]
    assert_equal '/v1/controllers/front/doors/1/unlock', @requests.last[:path]
  end

  test 'status maps door-api shape to the show_status shape' do
    @body = '{"id":"front","doors":[{"door":1,"locked":true},{"door":2,"locked":false}]}'
    status = DoorApiClient.new.status
    assert_equal true, status[:door_1_locked]
    assert_equal false, status[:door_2_locked]
    assert_equal true, status[:unlocked] # door 2 is unlocked
  end

  test 'sync posts the card set and returns the summary' do
    @body = '{"added":2,"updated":0,"unchanged":0,"removed":0,"failed":[]}'
    result = DoorApiClient.new.sync(:cards => [{ :card => 1, :doors => [1] }])
    assert_equal 2, result['added']
    assert_equal '/v1/controllers/front/cards/sync', @requests.last[:path]
  end

  test 'put_card returns false on an error response' do
    @status_line = 'HTTP/1.1 503 Service Unavailable'
    @body = '{"error":"circuit_open"}'
    assert_equal false, DoorApiClient.new.put_card(:number => 1, :doors => [1])
  end

  test 'Card#upload_to_door routes through door-api, hex card_number -> decimal' do
    APP_CONFIG['door_backend'] = 'door_api'
    @body = '{"ok":true,"message":"written"}'
    card = Card.new(:user_id => 1, :card_number => '261019f', :card_permissions => 1)
    assert_equal true, card.upload_to_door
    req = @requests.last
    assert_equal 'PUT', req[:method]
    assert_equal "/v1/controllers/front/cards/#{0x261019f}", req[:path]
    assert_equal [1, 2], JSON.parse(req[:body])['doors']
  end

  test 'a disabled card syncs with no doors' do
    card = Card.new(:user_id => 1, :card_number => 'beef', :card_permissions => 255)
    assert_equal [], card.door_access_list
  end

  test 'DoorLog.execute_command maps unlock-front to door-api door 1' do
    APP_CONFIG['door_backend'] = 'door_api'
    @body = '{"ok":true,"message":"door 1 unlock"}'
    DoorLog.execute_command('unlock-front')
    assert(@requests.any? { |r| r[:method] == 'POST' && r[:path] == '/v1/controllers/front/doors/1/unlock' })
  end

  private

  def serve
    loop do
      client = @server.accept
      request_line = client.gets
      method, path, = request_line.split(' ')
      headers = {}
      while (line = client.gets) && line != "\r\n"
        k, v = line.split(': ', 2)
        headers[k.downcase] = v.to_s.strip
      end
      body = nil
      if (len = headers['content-length'])
        body = client.read(len.to_i)
      end
      @requests << { :method => method, :path => path, :headers => headers, :body => body }
      payload = @body || '{}'
      status_line = @status_line || 'HTTP/1.1 200 OK'
      client.write("#{status_line}\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
      client.close
    end
  rescue IOError, Errno::EBADF
    # server closed during teardown
  end
end
