# The LED marquee in the lab's front window: a 30 by 8 pixel sign that shows
# the clock, a robot, HEATSYNC LABS and, while the doors are open, OPEN HOURS /
# COME IN. Members with door access can put a message up from the Devices page.
#
# This module holds the rules for what may be sent: the colours on offer, how
# a message is cleaned, and the one-tap presets. Marquee::Client does the
# talking and Marquee::Rotation edits what plays between messages.
module Marquee
  # The panel's font covers printable ASCII only; anything else would show as "?".
  MESSAGE_MAX = 100
  FRAME_MAX = 12          # words in a run of still frames
  # OPEN held still (it fits the 30 pixel panel), then the sentence scrolls.
  OPEN_FRAMES = "OPEN|OPEN HOURS - WE'RE OPEN - COME IN - {until}".freeze
  CONSOLE_URL = "https://heatsynclabs.github.io/marquee/".freeze
  REPO_URL = "https://github.com/heatsynclabs/marquee".freeze

  # label => what the panel takes. Picked to read well on the LEDs.
  COLORS = {
    "Orange"  => "#ff9f43",
    "White"   => "#ffffff",
    "Green"   => "#33ff66",
    "Cyan"    => "#20e0ff",
    "Pink"    => "#ff5a9a",
    "Yellow"  => "#ffd000",
    "Rainbow" => "rainbow",
  }.freeze

  # How many times a message goes by.
  REPEATS = { "Once" => 1, "3 times" => 3, "10 times" => 10 }.freeze

  # label => brightness 0-255. The panel's power limit caps the top end anyway.
  BRIGHTNESS = { "Low" => 25, "Normal" => 60, "Bright" => 140 }.freeze

  Preset = Data.define(:key, :label, :hint, :command)

  # One-tap buttons. Each plays now and then the sign goes back to its rotation.
  PRESETS = [
    Preset.new("open", "Open Hours", "OPEN, then WE'RE OPEN - COME IN, twice",
               { "cards" => OPEN_FRAMES, "color" => "#33ff66", "repeat" => 2, "now" => true }),
    Preset.new("robot", "Robot", "The robot walks, waves and flies by",
               { "anim" => "robot", "hold" => 23_500, "now" => true }),
    Preset.new("clock", "Clock", "The time, for 15 seconds",
               { "anim" => "clock", "hold" => 15_000, "now" => true }),
    Preset.new("normal", "Back to normal", "Drop any waiting messages",
               { "clear" => true }),
  ].freeze

  # Friendlier names for what the panel reports it is showing.
  SHOWING = { "robot" => "the robot", "clock" => "the clock", "off" => "nothing (blank)",
              "solid" => "a solid colour" }.freeze

  STRAIGHTEN = { "\u2018" => "'", "\u2019" => "'", "\u201C" => '"', "\u201D" => '"',
                 "\u2013" => "-", "\u2014" => "-", "\u2026" => "..." }.freeze

  module_function

  # Printable ASCII only, curly quotes and dashes straightened, spaces
  # collapsed, cut to max. Returns "" when nothing printable is left.
  def clean_text(text, max = MESSAGE_MAX)
    text.to_s
        .gsub(/[\u2018\u2019\u201C\u201D\u2013\u2014\u2026]/, STRAIGHTEN)
        .gsub(/[^\x20-\x7E]/, " ")
        .squeeze(" ")
        .strip[0, max].to_s.strip
  end

  # "OPEN | come in |" => "OPEN|come in"; keeps the {until} token. The sign
  # holds 127 characters for the whole run.
  def clean_frames(text)
    text.to_s.split("|").map { |frame| clean_text(frame, 60) }.reject(&:empty?).first(FRAME_MAX).join("|")[0, 120]
  end

  def color_value(label)
    COLORS[label.to_s] || COLORS["Orange"]
  end

  def color_label(value)
    COLORS.key(value.to_s.downcase) || "Orange"
  end

  def preset(key)
    PRESETS.find { |p| p.key == key.to_s }
  end

  # The command for a member's message, or nil when there is nothing to send.
  def message_command(text:, color:, repeat:)
    words = clean_text(text)
    return nil if words.empty?
    times = REPEATS.value?(repeat.to_i) ? repeat.to_i : 1
    { "text" => words, "color" => color_value(color), "repeat" => times }
  end

  # What the panel is showing, in words, from its /api/state "current".
  def showing(current)
    return "unknown" unless current.is_a?(Hash)
    arg = current["arg"].to_s
    case current["kind"]
    when "text"   then "“#{arg}”"
    when "cards"  then arg.gsub(/\s*-?\s*\{until\}/, "").split("|").map(&:strip).reject(&:empty?).join(" / ")
    when "stored" then "the #{arg} animation"
    else SHOWING.fetch(arg, arg.presence || "unknown")
    end
  end
end
