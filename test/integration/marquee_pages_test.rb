require "test_helper"
require "minitest/mock"

# The Devices page and the window sign page, signed in for real. The sign is
# replaced by a fake client, so these run without hardware.
class MarqueePagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Records what would have gone to the sign; raises if told to.
  class FakeSign
    attr_reader :sent

    def initialize(fail_with: nil, state: nil, rotation: nil)
      @fail_with = fail_with
      @state = state || { "fw" => "1.1.2", "uptime_s" => 3600, "brightness" => 60, "queued" => 0,
                          "time" => "2026-11-25 20:41:00",
                          "current" => { "kind" => "anim", "arg" => "robot" },
                          "status" => { "valid" => true, "on" => true, "until" => "21:00" } }
      @rotation = rotation || { "ms" => 15000, "items" => [{ "anim" => "clock" }, { "anim" => "fire" }],
                                "open" => { "cards" => "OPEN|HOURS", "color" => "#33ff66" } }
      @sent = []
    end

    def check!
      raise @fail_with if @fail_with
    end

    def state = (check!; @state)
    def rotation = (check!; @rotation)
    def command(cmd) = (check!; @sent << [:command, cmd]; { "ok" => true })
    def set_rotation(doc) = (check!; @sent << [:rotation, doc]; { "ok" => true })
    def poll_status = (check!; @sent << [:poll]; { "ok" => true })
    def reboot = (check!; @sent << [:reboot]; { "ok" => true })
  end

  def member(admin: false, card: false)
    user = User.new(name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    orientation: Date.current - 30, postal_code: "85201", current_skills: "x",
                    desired_skills: "x", marketing_source: "x", admin: admin)
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    Card.create!(user_id: user.id, card_number: SecureRandom.hex(4), card_permissions: 1) if card
    user
  end

  def with_sign(sign = FakeSign.new, &block)
    Marquee::Client.stub(:new, sign, &block)
    sign
  end

  setup { Rails.cache.clear }

  test "only card holders and admins see Devices" do
    get devices_path
    assert_redirected_to new_user_session_path

    sign_in member
    get devices_path
    assert_redirected_to root_path
    get marquee_path
    assert_redirected_to root_path
    post marquee_message_path, params: { text: "hi" }
    assert_redirected_to root_path
    get root_path
    assert_select "a[href=?]", devices_path, count: 0
  end

  test "a card holder sends a message and it is logged, not echoed as HTML" do
    sign_in member(card: true)
    get root_path
    assert_select "a[href=?]", devices_path
    get marquee_path
    assert_response :success
    assert_select "turbo-frame#marquee-panel[src=?]", marquee_panel_path
    assert_select "turbo-frame#marquee-rotation", count: 0 # admins only

    sign = with_sign do
      post marquee_message_path, params: { text: "<b>HI</b> — come in", color: "Cyan", repeat: "3" }
    end
    assert_redirected_to marquee_path
    assert_equal [[:command, { "text" => "<b>HI</b> - come in", "color" => "#20e0ff", "repeat" => 3 }]], sign.sent
    event = AuditEvent.where(event_type: "marquee.message").last
    assert_match "<b>HI</b>", event.summary
    follow_redirect!
    assert_no_match "<b>HI</b>", response.body # not in the flash, which is rendered raw
  end

  test "an empty message is refused before anything is sent" do
    sign_in member(card: true)
    sign = with_sign { post marquee_message_path, params: { text: "   " } }
    assert_empty sign.sent
    assert_equal "Type something to show first.", flash[:alert]
  end

  test "presets and brightness send the fixed commands" do
    sign_in member(card: true)
    sign = with_sign do
      post marquee_preset_path, params: { key: "open" }
      post marquee_preset_path, params: { key: "nope" }
      post marquee_brightness_path, params: { level: "Low" }
      post marquee_brightness_path, params: { level: "255" }
    end
    assert_equal [[:command, Marquee.preset("open").command], [:command, { "brightness" => 25 }]], sign.sent
  end

  test "a sign that does not answer is said plainly and nothing breaks" do
    sign_in member(card: true)
    down = FakeSign.new(fail_with: Marquee::Client::Unreachable.new("the sign is not answering (OpenTimeout)"))
    with_sign(down) do
      post marquee_message_path, params: { text: "hi" }
      assert_redirected_to marquee_path
      assert_match "did not answer", flash[:alert]

      get marquee_panel_path
      assert_response :success
      assert_select ".sign-status.offline", /Not answering/
    end
  end

  test "the live status reads the sign in words" do
    sign_in member(card: true)
    with_sign { get marquee_panel_path }
    assert_response :success
    assert_select ".sign-status.online .sign-now strong", "the robot"
    assert_match "Lab open until 9:00 PM", response.body
    assert_match "Sign clock 8:41 PM", response.body
  end

  test "card holders cannot change the rotation, restart or poll" do
    sign_in member(card: true)
    sign = with_sign do
      get marquee_rotation_path
      patch marquee_update_rotation_path, params: { rotation: { clock: "1" } }
      post marquee_restart_path
      post marquee_poll_path
    end
    assert_empty sign.sent
  end

  test "an admin edits the rotation and entries the form does not cover are kept" do
    sign_in member(admin: true)
    get marquee_path
    assert_select "turbo-frame#marquee-rotation[src=?]", marquee_rotation_path

    sign = with_sign do
      get marquee_rotation_path
      assert_response :success
      assert_select "input[type=checkbox][name='rotation[clock]'][checked]"
      assert_match "fire", response.body

      patch marquee_update_rotation_path, params: { rotation: {
        clock: "0", robot: "1", open_enabled: "1", open_frames: "OPEN|COME|IN", seconds: "20",
        texts: { "0" => { text: "HEATSYNC LABS", color: "Orange" } } } }
    end
    assert_redirected_to marquee_path
    kind, doc = sign.sent.last
    assert_equal :rotation, kind
    assert_equal [{ "text" => "HEATSYNC LABS", "color" => "#ff9f43" }, { "anim" => "robot", "hold" => 23500 },
                  { "anim" => "fire" }], doc["items"]
    assert_equal "OPEN|COME|IN", doc["open"]["cards"]
    assert AuditEvent.exists?(event_type: "marquee.rotation")
  end

  test "an admin saving an empty rotation is told why and nothing is sent" do
    sign_in member(admin: true)
    sign = with_sign(FakeSign.new(rotation: { "items" => [] })) do
      patch marquee_update_rotation_path, params: { rotation: { clock: "0", robot: "0" } }
    end
    assert_equal [], sign.sent
    assert_match "at least one", flash[:alert]
  end

  test "messages are rate limited per member" do
    sign_in member(card: true)
    sign = with_sign do
      8.times { post marquee_message_path, params: { text: "hi" } }
    end
    assert_equal 6, sign.sent.size
    assert_match "a lot of messages", flash[:alert]
  end

  # ---- the space API's closing time, which the sign reads ----

  test "the space API says when Open Hours ends while the doors are open" do
    closes = Time.zone.parse("2026-11-25 21:00")
    DoorLog.stub(:show_status, { unlocked: true, door_1_locked: false, door_2_locked: false }) do
      LabCalendar.stub(:open_hours_until, closes) { get space_api_path(format: :json) }
    end
    json = JSON.parse(response.body)
    assert_equal true, json["open"]
    assert_equal "21:00", json["open_until"]
  end

  test "no closing time when the doors are locked or nothing is scheduled" do
    DoorLog.stub(:show_status, { unlocked: false, door_1_locked: true, door_2_locked: true }) do
      LabCalendar.stub(:open_hours_until, -> { flunk "not asked while closed" }) { get space_api_path(format: :json) }
    end
    refute JSON.parse(response.body).key?("open_until")

    DoorLog.stub(:show_status, { unlocked: true, door_1_locked: false, door_2_locked: false }) do
      LabCalendar.stub(:open_hours_until, nil) { get space_api_path(format: :json) }
    end
    refute JSON.parse(response.body).key?("open_until")
  end
end
