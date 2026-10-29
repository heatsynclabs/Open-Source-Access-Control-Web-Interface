module DoorLogsHelper
  PREFIX_SOURCES = {
    'api_rem_' => 'Mobile App',
    'rem_'     => 'Web'
  }.freeze

  ACTIONS = {
    'l' => { action: 'locked',   klass_suffix: 'AccessLock'   },
    'o' => { action: 'open',     klass_suffix: 'AccessOpen'   },
    'u' => { action: 'unlocked', klass_suffix: 'AccessUnlock' }
  }.freeze

  # A Lucide icon name for where a remote command came from.
  def access_source_icon(source)
    source == PREFIX_SOURCES['api_rem_'] ? "smartphone" : "monitor"
  end

  def extract_access_info(door_log)
    key_base = door_log.key.split('=').first  # remove trailing "=1"
    prefix = PREFIX_SOURCES.keys.find { |p| key_base.start_with?(p) }

    # Extract action character right after the prefix (e.g., 'o' from 'api_rem_o1')
    suffix = prefix ? key_base[prefix.length] : nil

    if prefix && ACTIONS[suffix]
      action_data   = ACTIONS[suffix]
      source        = PREFIX_SOURCES[prefix]
      klass_prefix  = prefix.include?('api') ? 'mobile' : 'web'
      access_class  = "#{klass_prefix}#{action_data[:klass_suffix]}"
      access_action = action_data[:action]
      [source, access_class, access_action]
    else
      [nil, nil, nil]
    end
  end
end
