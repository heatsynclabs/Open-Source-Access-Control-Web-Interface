require 'test_helper'
require 'socket'
require 'minitest/mock'

# Exercises DoorApiClient, and the DoorLog and Card paths that use it, against a
# tiny in-process HTTP server standing in for door-api, so no real door-api or
# hardware is needed. The board replies used here are the firmware's exact bytes.
class DoorApiClientTest < ActiveSupport::TestCase
  BOARD_STATUS = { 'armed' => 4, 'activated' => 0, 'alarm_3' => 0, 'alarm_2' => 0,
                   'door_1_locked' => 1, 'door_2_locked' => 0 }.freeze

  # The board's ?z reply from <pre> on: 40 lines, unused entries are a NUL key.
  def board_log(lines)
    body = lines.map { |l| "#{l}\r\n" }.join
    body += "\u0000: 0\r\n" * (40 - lines.size)
    "<pre>\r\n#{body}</pre>\r\n"
  end

  def setup
    @requests = []
    @responses = {} # "METHOD path" => [status_line, body]
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
    @saved = APP_CONFIG.slice('door_api_url', 'door_controller', 'door_api_key', 'door_backend')
    APP_CONFIG['door_api_url'] = "http://127.0.0.1:#{@port}"
    APP_CONFIG['door_controller'] = 'front'
    APP_CONFIG['door_api_key'] = 'testkey'
    APP_CONFIG['door_backend'] = 'door_api'
    respond('GET /v1/controllers/front/status', 200, { 'id' => 'front', 'details' => BOARD_STATUS })
  end

  def teardown
    @server.close rescue nil
    @thread.kill rescue nil
    APP_CONFIG.merge!(@saved)
  end

  def respond(key, code, body)
    @responses[key] = [code, body.to_json]
  end

  def paths
    @requests.map { |r| "#{r[:method]} #{r[:path]}" }
  end

  # ---- doors: every command reaches the board as the same query ----

  test 'each remote command maps to the door-api call for the same board query' do
    expected = {
      'open-front' => 'POST /v1/controllers/front/doors/1/open',     # ?o1
      'open-rear' => 'POST /v1/controllers/front/doors/2/open',      # ?o2
      'unlock' => 'POST /v1/controllers/front/doors/unlock',         # ?u
      'u' => 'POST /v1/controllers/front/doors/unlock',
      'unlock-front' => 'POST /v1/controllers/front/doors/1/unlock', # ?u=1
      'u1' => 'POST /v1/controllers/front/doors/1/unlock',
      'unlock-rear' => 'POST /v1/controllers/front/doors/2/unlock',  # ?u=2 (callers refuse it)
      'lock' => 'POST /v1/controllers/front/doors/lock',             # ?l, no chirp
      'l' => 'POST /v1/controllers/front/doors/lock',
      'lock-front' => 'POST /v1/controllers/front/doors/1/lock',     # ?l=1
      'l1' => 'POST /v1/controllers/front/doors/1/lock',
      'lock-rear' => 'POST /v1/controllers/front/doors/2/lock',      # ?l=2
      'l2' => 'POST /v1/controllers/front/doors/2/lock',
      'arm' => 'POST /v1/controllers/front/alarm/arm',               # ?2
      'disarm' => 'POST /v1/controllers/front/alarm/disarm'          # ?1
    }
    expected.each do |command, call|
      @requests.clear
      output = DoorLog.execute_command(command, actor: 'user 7')
      assert_equal [call, 'GET /v1/controllers/front/status'], paths, command
      assert_equal DoorLog.parse_command(command)[:output], output, command
      assert_equal 'user 7', @requests.first[:headers]['x-door-actor']
      assert_equal 'Bearer testkey', @requests.first[:headers]['authorization']
    end
  end

  test 'an unknown command only refreshes the status, like the direct path (?9)' do
    assert_equal "Fail. Don't be a naughty user!", DoorLog.execute_command('rm -rf')
    assert_equal ['GET /v1/controllers/front/status'], paths
  end

  test 'door-api errors give the direct path message; busy says try again' do
    respond('POST /v1/controllers/front/doors/1/open', 503, { 'error' => 'controller_unreachable' })
    assert_equal 'Failed to connect to door system.', DoorLog.execute_command('open-front')
    respond('POST /v1/controllers/front/doors/1/open', 503, { 'error' => 'busy' })
    assert_equal 'The door system is busy. Try again in a moment.', DoorLog.execute_command('open-front')
  end

  test 'u2 counts as a rear unlock' do
    assert DoorLog.rear_unlock?('u2')
    assert DoorLog.rear_unlock?('unlock-rear')
    assert_not DoorLog.rear_unlock?('unlock')
    assert_not DoorLog.rear_unlock?('open-rear')
  end

  # ---- status: the same rows as the direct path ----

  test 'download_status stores every board field in the board order, like the direct path' do
    DoorLog.delete_all
    assert_equal BOARD_STATUS, DoorLog.download_status
    rows = DoorLog.order(:id).pluck(:key, :data)
    assert_equal BOARD_STATUS.to_a, rows
    status = DoorLog.show_status
    assert_equal true, status[:door_1_locked]
    assert_equal false, status[:door_2_locked]
    assert_equal true, status[:unlocked]
  end

  # ---- event log ----

  test 'the import saves the same rows the direct path would, then acknowledges each drain' do
    DoorLog.delete_all
    raw1 = board_log(['U: 1', 'L: 1', 'G: 4660', 'g: 0'])
    raw2 = board_log(['D: 30000', 'd: 2'])
    respond('POST /v1/controllers/front/log/drain', 200,
            { 'drains' => [{ 'drain_id' => 'a', 'raw' => raw1, 'cleared' => true },
                           { 'drain_id' => 'b', 'raw' => raw2, 'cleared' => true }] })
    respond('POST /v1/controllers/front/log/ack', 200, { 'ok' => true })
    results = DoorLog.download_from_door
    assert_equal 80, results.size
    assert_equal [%w[U 1], %w[L 1], %w[G 4660], %w[g 0], %w[D 30000], %w[d 2]],
                 DoorLog.order(:id).pluck(:key, :data).map { |k, d| [k, d.to_s] }
    acks = @requests.select { |r| r[:path].end_with?('/log/ack') }.map { |r| JSON.parse(r[:body])['drain_id'] }
    assert_equal %w[a b], acks
    # the same parse the direct path does on the same bytes
    direct = raw1.scan(/(.*): (.*)\r\n/).reject { |r| r[0] == "\000" }
    assert_equal direct, [%w[U 1], %w[L 1], %w[G 4660], %w[g 0]]
  end

  test 'a failed save is not acknowledged, so door-api keeps the drain' do
    DoorLog.delete_all
    respond('POST /v1/controllers/front/log/drain', 200,
            { 'drains' => [{ 'drain_id' => 'a', 'raw' => board_log(['U: 1']), 'cleared' => true }] })
    DoorLog.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid }) do
      assert_raises(ActiveRecord::RecordInvalid) { DoorLog.download_from_door }
    end
    assert(@requests.none? { |r| r[:path].end_with?('/log/ack') })
  end

  test 'an unreachable door-api imports nothing and returns false' do
    respond('POST /v1/controllers/front/log/drain', 503, { 'error' => 'controller_unreachable' })
    assert_equal false, DoorLog.download_from_door
  end

  # ---- cards ----

  def card(attrs = {})
    user = User.first || users(:one)
    Card.create!({ :id => 42, :user_id => user.id, :card_number => '12abcd', :card_permissions => 1 }.merge(attrs))
  end

  test 'upload_to_door writes slot = card id with the tag and mask' do
    respond('PUT /v1/controllers/front/slots/42', 200, { 'ok' => true })
    c = card
    assert_equal true, c.upload_to_door
    req = @requests.last
    assert_equal 'PUT /v1/controllers/front/slots/42', "#{req[:method]} #{req[:path]}"
    assert_equal({ 'tag' => '12abcd', 'mask' => 1 }, JSON.parse(req[:body]))
  end

  test 'upload_to_door is false when door-api refuses' do
    respond('PUT /v1/controllers/front/slots/42', 502, { 'error' => 'controller_bad_reply' })
    assert_equal false, card.upload_to_door
  end

  test 'upload_all_to_door writes every card, one slot each' do
    respond('PUT /v1/controllers/front/slots/42', 200, { 'ok' => true })
    respond('PUT /v1/controllers/front/slots/43', 503, { 'error' => 'controller_unreachable' })
    Card.delete_all
    card
    card(:id => 43, :card_number => 'beef', :card_permissions => 255)
    assert_equal [%w[042 OK], %w[043 FAIL]], Card.upload_all_to_door.sort
  end

  test 'deleting a card clears its board slot first' do
    respond('DELETE /v1/controllers/front/slots/42', 200, { 'ok' => true })
    c = card
    assert c.destroy
    assert_equal 'DELETE /v1/controllers/front/slots/42', paths.last
    assert_not Card.exists?(42)
  end

  test 'a card is kept when the board does not confirm the delete' do
    respond('DELETE /v1/controllers/front/slots/42', 503, { 'error' => 'controller_unreachable' })
    c = card
    assert_not c.destroy
    assert Card.exists?(42)
    assert_match(/not deleted/, c.errors.full_messages.to_sentence)
  end

  test 'a card outside the board slots is deleted without touching the board' do
    c = Card.new(:id => 250, :user_id => (User.first || users(:one)).id, :card_number => 'abc250', :card_permissions => 1)
    c.save!(:validate => false) # an old row from before the slot check
    assert c.destroy
    assert_empty @requests.select { |r| r[:method] == 'DELETE' }
  end

  test 'a new card must use a board slot from 10 to 199' do
    user = User.first || users(:one)
    [5, 200, 1000].each do |slot|
      c = Card.new(:id => slot, :user_id => user.id, :card_number => "ab#{slot}", :card_permissions => 1)
      assert_not c.valid?, "slot #{slot}"
      assert c.errors[:id].any?
    end
    assert Card.new(:id => 199, :user_id => user.id, :card_number => 'ab199', :card_permissions => 1).valid?
  end

  test 'card writes and deletes tell door-api who made them' do
    respond('PUT /v1/controllers/front/slots/42', 200, { 'ok' => true })
    respond('DELETE /v1/controllers/front/slots/42', 200, { 'ok' => true })
    c = card
    c.door_actor = 'user 7'
    c.upload_to_door
    assert_equal 'user 7', @requests.last[:headers]['x-door-actor']
    c.destroy
    assert_equal 'user 7', @requests.last[:headers]['x-door-actor']
  end

  test 'only one import runs at a time' do
    # A second, independent database session holds the import lock.
    info = DoorLog.connection.raw_connection.conninfo_hash.slice(:host, :port, :dbname, :user, :password).compact
    other = PG.connect(info)
    begin
      other.exec("SELECT pg_advisory_lock(#{DoorLog::IMPORT_LOCK})")
      assert_equal false, DoorLog.download_from_door
      assert(@requests.none? { |r| r[:path].end_with?('/log/drain') })
    ensure
      other.exec("SELECT pg_advisory_unlock(#{DoorLog::IMPORT_LOCK})")
      other.close
    end
    respond('POST /v1/controllers/front/log/drain', 200, { 'drains' => [] })
    assert_equal false, DoorLog.download_from_door # nothing to import, but it ran
    assert(@requests.any? { |r| r[:path].end_with?('/log/drain') })
  end

  test 'the slot range stops at 199' do
    assert_equal 199, Card::SLOT_RANGE.last
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
      code, payload = @responses["#{method} #{path}"] || [200, '{"ok":true}']
      client.write("HTTP/1.1 #{code} X\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
      client.close
    end
  rescue IOError, Errno::EBADF
    # server closed during teardown
  end
end
