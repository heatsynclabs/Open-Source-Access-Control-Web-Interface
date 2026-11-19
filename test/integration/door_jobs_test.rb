require "test_helper"
require "minitest/mock"

# DOOR_JOBS=off (staging) stops the scheduled door work: the log import and
# the after-hours lock. Members' own door actions keep working.
class DoorJobsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def user(id: nil, card: false)
    user = User.new(name: "Test Member", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.id = id if id
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    Card.create!(user_id: user.id, card_number: SecureRandom.hex(4), card_permissions: 1) if card
    user
  end

  def refuse_board
    ->(*) { flunk "the door board was contacted" }
  end

  setup { @saved = ENV["DOOR_JOBS"] }
  teardown { ENV["DOOR_JOBS"] = @saved }

  test "jobs are on unless DOOR_JOBS is off" do
    ENV.delete("DOOR_JOBS")
    assert DoorBoard.jobs_enabled?
    ENV["DOOR_JOBS"] = "on"
    assert DoorBoard.jobs_enabled?
    ENV["DOOR_JOBS"] = " OFF "
    assert_not DoorBoard.jobs_enabled?
  end

  test "the log import does not touch the board when door jobs are off" do
    ENV["DOOR_JOBS"] = "off"
    DoorLog.stub(:download_from_door, refuse_board) do
      post auto_download_path
    end
    assert_response :forbidden
    assert_equal DoorBoard::JOBS_OFF_MESSAGE, response.body
  end

  test "the log import runs when door jobs are on" do
    ENV.delete("DOOR_JOBS")
    calls = 0
    DoorLog.stub(:download_from_door, -> { calls += 1; [] }) do
      DoorLog.stub(:download_status, nil) do
        post auto_download_path(format: :json)
      end
    end
    assert_response :success
    assert_equal 1, calls
  end

  test "the log import only answers the scheduled task inside the container" do
    ENV.delete("DOOR_JOBS")
    DoorLog.stub(:download_from_door, refuse_board) do
      post auto_download_path, env: { "REMOTE_ADDR" => "10.0.1.7" }
    end
    assert_response :forbidden
    DoorLog.stub(:download_from_door, refuse_board) do
      post auto_download_path, headers: { "X-Forwarded-For" => "127.0.0.1" }, env: { "REMOTE_ADDR" => "10.0.1.7" }
    end
    assert_response :forbidden
  end

  test "u2 is refused like unlock-rear" do
    sign_in user(card: true)
    %w[u2 unlock-rear].each do |cmd|
      DoorLog.stub(:execute_command, refuse_board) do
        post "/space_api/access.json", params: { cmd: cmd }
      end
      assert_includes response.body, "no longer allowed"
    end
  end

  test "the after-hours lock account does nothing when door jobs are off" do
    ENV["DOOR_JOBS"] = "off"
    sign_in user(id: DoorLogsHelper::AUTOMATIC_LOCK_ID, card: true)
    assert_no_difference -> { DoorLog.count } do
      DoorLog.stub(:execute_command, refuse_board) do
        post "/space_api/access.json", params: { cmd: "lock" }
      end
    end
    assert_includes response.body, "DOOR_JOBS=off"
  end

  test "a member can still lock the door when door jobs are off" do
    ENV["DOOR_JOBS"] = "off"
    sign_in user(card: true)
    commands = []
    assert_difference -> { DoorLog.count }, 1 do
      DoorLog.stub(:execute_command, ->(cmd, **) { commands << cmd; "Locked." }) do
        post "/space_api/access.json", params: { cmd: "lock" }
      end
    end
    assert_equal ["lock"], commands
  end
end
