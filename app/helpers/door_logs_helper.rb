module DoorLogsHelper
  PREFIX_SOURCES = {
    'api_rem_' => 'Mobile App',
    'rem_'     => 'Web'
  }.freeze

  ACTIONS = {
    'l' => 'locked',
    'o' => 'open',
    'u' => 'unlocked'
  }.freeze

  # Remote commands carry the member's id as data; this id is the after-hours lock.
  AUTOMATIC_LOCK_ID = 468
  # The board logs a card number as two values, the high part times this plus the low part.
  CARD_HALF = 32767
  CARD_VERBS = { "R" => "Read", "D" => "Denied", "G" => "Granted" }.freeze
  CARD_TONES = { "G" => "tone-ok", "D" => "tone-err" }.freeze

  DoorLogLine = Struct.new(:log, :meaning, :tone, :icon)

  # What each row of the door log means, worked out for the whole page at
  # once: names and cards are looked up in one query each instead of one or
  # two per row.
  def door_log_lines(door_logs)
    logs = door_logs.to_a
    card_numbers = card_numbers_by_log(logs)
    cards = Card.where("lower(card_number) IN (?)", card_numbers.values.map(&:downcase).uniq).includes(:user)
      .index_by { |card| card.card_number.downcase }
    names = User.where(id: remote_member_ids(logs)).pluck(:id, :name).to_h

    logs.map do |log|
      if card_numbers[log.id]
        number = card_numbers[log.id]
        holder = cards[number.downcase]&.user
        DoorLogLine.new(log, "#{CARD_VERBS[log.key]} card #{number}#{" (#{holder.name})" if holder}", CARD_TONES[log.key])
      elsif remote_command?(log)
        describe_remote(log, names)
      else
        DoorLogLine.new(log)
      end
    end
  end

  # A Lucide icon name for where a remote command came from.
  def access_source_icon(source)
    source == PREFIX_SOURCES['api_rem_'] ? "smartphone" : "monitor"
  end

  # [source, action] for a remote command key like "api_rem_o1", or nils.
  def extract_access_info(door_log)
    key_base = door_log.key.split('=').first  # remove trailing "=1"
    prefix = PREFIX_SOURCES.keys.find { |p| key_base.start_with?(p) }
    action = prefix && ACTIONS[key_base[prefix.length]]
    action ? [PREFIX_SOURCES[prefix], action] : [nil, nil]
  end

  private

  # Card events arrive as two rows: the lower-case half (r, d, g) first, then
  # the upper-case one (R, D, G), which completes the number.
  def card_numbers_by_log(logs)
    high_half = nil
    logs.each_with_object({}) do |log, numbers|
      if %w[r d g].include?(log.key)
        high_half = log.data.to_i
      elsif %w[R D G].include?(log.key) && high_half
        numbers[log.id] = (log.data.to_i + (high_half * CARD_HALF)).to_s(16)
      else
        high_half = nil
      end
    end
  end

  def remote_command?(log)
    log.key.start_with?("rem_", "api_rem_") && log.data.to_s.match?(/\A\d+\z/)
  end

  def remote_member_ids(logs)
    logs.select { |log| remote_command?(log) }.map { |log| log.data.to_i }.uniq - [AUTOMATIC_LOCK_ID]
  end

  def describe_remote(log, names)
    return DoorLogLine.new(log, "Automatic locking", "tone-quiet") if log.data.to_i == AUTOMATIC_LOCK_ID
    source, action = extract_access_info(log)
    name = names[log.data.to_i]
    return DoorLogLine.new(log) unless name && source
    DoorLogLine.new(log, "Granted #{source}: #{name} (#{action})", "tone-info", access_source_icon(source))
  end
end
