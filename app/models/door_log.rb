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

  # Remote commands that would unlock the rear door. Refused by the remote page
  # and the phone API (HYH 2018-02-22). "u2" is the short form of "unlock-rear".
  REAR_UNLOCK_COMMANDS = %w[unlock-rear u2].freeze

  def self.rear_unlock?(command)
    REAR_UNLOCK_COMMANDS.include?(command.to_s)
  end

  # actor (optional) is recorded in door-api's audit trail, e.g. "user 12".
  def self.execute_command(command, actor: nil)
    return execute_command_via_api(command, actor: actor) if DoorApiClient.enabled?

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

  # The door-api call that sends the board the same query as the direct path.
  # Derived from parse_command's url_param, so the two paths cannot drift apart:
  #   o1/o2 -> open one door      u -> unlock all (?u)    u=1/u=2 -> unlock one
  #   l -> lock all (?l)          l=1/l=2 -> lock one     2 -> arm, 1 -> disarm
  #   9 (an unknown command) -> nothing, just the status refresh
  def self.door_api_call(url_param)
    case url_param
    when /\Ao([12])\z/ then [:door, $1.to_i, 'open']
    when 'u' then [:all_doors, 'unlock']
    when /\Au=([12])\z/ then [:door, $1.to_i, 'unlock']
    when 'l' then [:all_doors, 'lock']
    when /\Al=([12])\z/ then [:door, $1.to_i, 'lock']
    when '2' then [:alarm, 'arm']
    when '1' then [:alarm, 'disarm']
    end
  end

  # Run a door command through door-api. Returns the same message as the direct
  # path, so callers (space_api, api/v1/doors) are unchanged.
  def self.execute_command_via_api(command, actor: nil)
    parsing = parse_command(command)
    call = door_api_call(parsing[:url_param])
    DoorApiClient.new(:actor => actor).public_send(call.first, *call.drop(1)) if call
    download_status # refresh the DB status cache, as the direct path does
    parsing[:output]
  rescue DoorApiClient::Error => e
    return 'The door system is busy. Try again in a moment.' if e.code == 'busy'
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

  # Pull the board's status through door-api and store every field it printed,
  # in its order, exactly as the direct path does (armed, activated, alarm_3,
  # alarm_2, door_1_locked, door_2_locked).
  def self.download_status_via_api
    status = DoorApiClient.new.raw_status
    status.each do |key, value|
      DoorLog.create!({:key => key, :data => value})
    end
    status
  rescue DoorApiClient::Error
    nil
  end

  # Import the board's event buffer. The direct path logs in, reads (?z), saves
  # the rows, clears (?y) and logs out.
  def self.download_from_door
    return download_from_door_via_api if DoorApiClient.enabled?

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

  # Through door-api: it reads the buffer, journals it on disk, then clears the
  # board, and hands back every drain not yet acknowledged (oldest first). Each
  # is parsed with the same expression and filter as the direct path, saved in
  # one transaction, then acknowledged. A failure before the ack leaves the drain
  # in door-api's journal for the next run, so no event is lost.
  # One import at a time (the scheduled task and an admin's "download" could
  # otherwise both save the same unacknowledged drain): a Postgres advisory lock,
  # held only around the drain, save and acknowledge.
  IMPORT_LOCK = 4_240_001

  def self.download_from_door_via_api
    conn = DoorLog.connection
    # uncached: the query cache would otherwise answer a repeated lock query
    # from memory instead of asking Postgres.
    return false unless conn.uncached { conn.select_value("SELECT pg_try_advisory_lock(#{IMPORT_LOCK})") }
    begin
      import_drains_via_api
    ensure
      conn.uncached { conn.select_value("SELECT pg_advisory_unlock(#{IMPORT_LOCK})") }
    end
  end

  def self.import_drains_via_api
    client = DoorApiClient.new
    all = []
    client.drain.each do |d|
      results = d['raw'].to_s.scan(/(.*): (.*)\r\n/)
      DoorLog.transaction do
        results.each do |r|
          DoorLog.create!({:key => r[0], :data => r[1]}) if r[0] != "\000"
        end
      end
      client.ack(d['drain_id'])
      all.concat(results)
    end
    all.size > 0 ? all : false
  rescue DoorApiClient::Error
    all.to_a.size > 0 ? all : false
  end

  def self.key_legend
    {'G' => "Granted", "R" => "Read", "D" => "Denied",
    'g' => "granted", "r" => "read", "d" => "denied"}
  end
end
