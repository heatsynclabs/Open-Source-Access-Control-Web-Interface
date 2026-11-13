class DoorLog < ActiveRecord::Base
  require 'open-uri'

  # Optional type filter for the door log report. Keys in this table:
  #   G/g Granted, D/d Denied, R/r Read (card events, data = card number)
  #   L/U         Lock / Unlock actions (data = door number)
  #   door_N_locked  automatic lock-status polls (data = 0/1)
  #   rem_* / api_rem_*  remote web/mobile commands
  #   armed / activated / alarm_* / A/m/s/t/T   alarm + system polling
  # 'all' (the default) shows everything except the alarm/system polling noise.

  # [label, value] pairs for the report dropdown, in display order
  TYPE_OPTIONS = [
    ['All access & locking', 'all'],
    ['Card access (granted / denied / read)', 'card'],
    ['Automatic locking / unlocking', 'locking'],
    ['Remote access (web / mobile)', 'remote'],
    ['Alarm & system', 'alarm']
  ].freeze

  TYPES = TYPE_OPTIONS.map { |_label, value| value }.freeze

  def self.valid_type?(type)
    TYPES.include?(type)
  end

  # Relation filtered to one report type. All conditions are parameterized
  # (key sets and LIKE patterns are AR-escaped), so nothing here interpolates
  # a value into SQL; the type argument only selects a branch.
  def self.by_type(type)
    case type
    when 'card'
      where(:key => %w[G g D d R r C c])
    when 'locking'
      where(:key => %w[door_1_locked door_2_locked L U])
    when 'remote'
      where("key LIKE ?", "%rem%")
    when 'alarm'
      where("key LIKE ? OR key IN (?)", "alarm%", %w[armed activated A m s t T])
    else # 'all'
      where("key NOT LIKE ? AND key NOT IN (?)", "alarm%", %w[armed activated])
    end
  end

  # Legacy door command -> door-api (door number, action). :all applies the action
  # to every configured door. Alarm commands (arm/disarm) have no door-api
  # equivalent and are handled separately.
  DOOR_API_COMMANDS = {
    'unlock' => [:all, 'unlock'], 'u' => [:all, 'unlock'],
    'unlock-front' => [1, 'unlock'], 'u1' => [1, 'unlock'],
    'unlock-rear' => [2, 'unlock'], 'u2' => [2, 'unlock'],
    'lock' => [:all, 'lock'], 'l' => [:all, 'lock'],
    'lock-front' => [1, 'lock'], 'l1' => [1, 'lock'],
    'lock-rear' => [2, 'lock'], 'l2' => [2, 'lock'],
    'open-front' => [1, 'open'], 'open-rear' => [2, 'open']
  }.freeze

  def self.execute_command(command)
    return execute_command_via_api(command) if DoorApiClient.enabled?

    password = APP_CONFIG['door_access_password']

    # login; only continue if we got an OK login
    unless DoorBoard.get("e=#{password}").scan(/ok/).size > 0
      return 'Failed to connect to door system.'
    end

    parsing = parse_command(command)
    DoorBoard.get(parsing[:url_param]) # execute the command
    download_status                    # update the status cache
    logout(password)                   # best effort; board also auto-logs-out
    parsing[:output]
  rescue DoorBoard::Unreachable
    'Failed to connect to door system.'
  end

  # Run a door command through door-api. Mirrors the legacy return (the command's
  # friendly message) so callers (space_api, api/v1/doors) are unchanged.
  def self.execute_command_via_api(command)
    mapping = DOOR_API_COMMANDS[command]
    return 'Alarm control is not available through the door API.' if %w[arm disarm].include?(command)
    return parse_command(command)[:output] unless mapping # unknown -> legacy message

    door, action = mapping
    client = DoorApiClient.new
    doors = door == :all ? Array(APP_CONFIG['door_doors'] || [1, 2]) : [door]
    doors.each { |d| client.door(d, action) }
    download_status # refresh the DB status cache
    parse_command(command)[:output]
  rescue DoorApiClient::Error
    'Failed to connect to door system.'
  end

  # Tell the board to log out. Best effort: a failure here must not clobber the
  # result of a command that already ran, and the board logs itself out anyway.
  def self.logout(_password = nil)
    DoorBoard.get("e=0000")
  rescue DoorBoard::Unreachable
    nil
  end

  def self.parse_command(command)
    output = ""
    url_param = ""
      # @commands = [
      #   ["Unlock all doors","unlock"],
      #   ["Unlock Front door","unlock-front"],
      #   ["Unlock Rear door","unlock-rear"],
      #   ["Lock all doors","lock"],
      #   ["Lock Front door","lock-front"],
      #   ["Lock Rear door","lock-rear"],
      #   ["Open Front door","open-front"],
      #   ["Open Rear door","open-rear"],
      #   ["Arm alarm","arm"],
      #   ["Disarm alarm","disarm"]
      # ]
    case command
      when "open-front"
        output +=  "Front door opened."
        url_param = "o1"
      when "open-rear"
        output +=  "Rear door opened."
        url_param = "o2"
      when "u", "unlock"
        output +=  "Doors unlocked, remember to re-lock them."
        url_param = "u"
      when "u1", "unlock-front"
        output +=  "Front Door unlocked, remember to re-lock it."
        url_param = "u=1"
      when "u2", "unlock-rear"
        output +=  "Rear Door unlocked, remember to re-lock it."
        url_param = "u=2"
      when "lock", "l"
        output +=  "Doors locked."
        url_param = "l"
      when "lock-front", "l1"
        output +=  "Front Door locked."
        url_param = "l=1"
      when "lock-rear", "l2"
        output +=  "Rear Door locked."
        url_param = "l=2"
      when "arm"
        output +=  "Armed."
        url_param = "2"
      when "disarm"
        output +=  "Disarmed."
        url_param = "1"
      else
        output +=  "Fail. Don't be a naughty user!"
        url_param = "9" # Using 9 because it's just status, no harm done
    end
    return {:output => output, :url_param => url_param}
  end

  def self.show_status
    door_logs = DoorLog.order('created_at DESC').where(key: ["door_1_locked","door_2_locked"]).limit(2)
    door_1_locked = parse_locked_status(door_logs, "door_1_locked")
    door_2_locked = parse_locked_status(door_logs, "door_2_locked")

    # Doors are unlocked if 1 OR 2 are NOT locked
    status = {:unlocked => (!door_1_locked || !door_2_locked), :door_1_locked => door_1_locked, :door_2_locked => door_2_locked }
  end

  def self.parse_locked_status(door_logs, door_key)
    door_logs_selected = door_logs.select{|s| s.key == door_key }
    if door_logs_selected.present?
      door_data = door_logs_selected.first.data
      if door_data == 0 # 0 = unlocked
        return false
      else
        return true # 1 = locked
      end
    end
  end

  def self.download_status
    return download_status_via_api if DoorApiClient.enabled?

    # query for status
    source = DoorBoard.get("9")
    # expect {"armed"=>255, "activated"=>255, "alarm_3"=>1, "alarm_2"=>1, "door_1_locked"=>1, "door_2_locked"=>1}
    # See https://github.com/heatsynclabs/Open_Access_Control_Ethernet for more info
    status = JSON.parse(source)
    status.each do |key, value|
      DoorLog.create!({:key => key, :data => value})
    end
    status
  rescue DoorBoard::Unreachable
    nil
  end

  # Pull status from door-api and write the same door_N_locked rows the legacy
  # path writes, so show_status (a pure DB read) keeps working unchanged.
  def self.download_status_via_api
    status = DoorApiClient.new.status
    status.each do |key, value|
      next unless key.to_s =~ /\Adoor_\d+_locked\z/
      DoorLog.create!({:key => key.to_s, :data => (value ? 1 : 0)})
    end
    status
  rescue DoorApiClient::Error
    nil
  end

  # NOTE: event-log download stays on the legacy path for now. The board's buffer
  # has no read cursor (clear-on-read), so it does not map onto door-api's
  # incremental events(); that moves to door-api only after the UHPPOTE cutover,
  # whose events are index-stable. See door-api docs/MEMBERS-INTEGRATION.md.
  def self.download_from_door
    password = APP_CONFIG['door_access_password']

    # connect; only continue if we got an OK login
    return false unless DoorBoard.get("e=#{password}").scan(/ok/).size > 0

    # download the on-board log buffer
    source = DoorBoard.get("z")
    results = source.scan(/(.*): (.*)\r\n/)
    results.each do |r|
      DoorLog.create!({:key => r[0], :data => r[1]}) if r[0] != "\000"
    end

    DoorBoard.get("y") # clear the board log now that the rows are saved
    logout(password)

    results.size > 0 ? results : false
  rescue DoorBoard::Unreachable
    false
  end

  def self.key_legend
    {'G' => "Granted", "R" => "Read", "D" => "Denied",
    'g' => "granted", "r" => "read", "d" => "denied"}
  end
end
