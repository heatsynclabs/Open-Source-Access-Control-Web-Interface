# What the marquee shows between messages, as a simple form: the clock, the
# robot, up to three lines of text, and the Open Hours frames mixed in while
# the doors are open. Reads and writes the panel's rotation document:
#
#   { "ms" => 15000,
#     "items" => [{ "anim" => "clock" }, { "text" => "HEATSYNC LABS", "color" => "#ff9f43" },
#                 { "anim" => "robot", "hold" => 23200 }],
#     "open" => { "cards" => "OPEN|HOURS|...", "color" => "#33ff66" } }
#
# Entries the form has no field for (another effect, a stored animation) are
# kept, after the ones it edits, so saving never drops something set elsewhere.
module Marquee
  class Rotation
    include ActiveModel::Model
    include ActiveModel::Attributes

    MAX_ITEMS = 6           # the panel keeps six
    TEXT_LINES = 3
    ROBOT_HOLD = 23_500     # one full robot routine

    attribute :clock, :boolean, default: true
    attribute :robot, :boolean, default: true
    attribute :open_enabled, :boolean, default: true
    attribute :open_frames, :string, default: OPEN_FRAMES
    attribute :seconds, :integer, default: 15

    attr_accessor :texts   # [{ "text" => ..., "color" => label }] x TEXT_LINES
    attr_accessor :extras  # panel items kept as they are

    validates :seconds, numericality: { only_integer: true, in: 5..120 }
    validate :fits_the_panel

    def initialize(attributes = {})
      attributes = attributes.to_h.symbolize_keys
      texts = attributes.delete(:texts)
      extras = attributes.delete(:extras)
      super(attributes)
      self.texts = normalize_texts(texts)
      self.extras = Array(extras).select { |item| item.is_a?(Hash) }
    end

    def self.from_panel(doc)
      doc = {} unless doc.is_a?(Hash)
      items = Array(doc["items"]).select { |item| item.is_a?(Hash) }
      texts = items.select { |item| item["text"] }.map do |item|
        { "text" => item["text"], "color" => item["color"] == "rainbow" ? "Rainbow" : Marquee.color_label(item["color"]) }
      end
      extras = items.reject { |item| item["text"] || %w[clock robot].include?(item["anim"]) }
      open = doc["open"].is_a?(Hash) ? doc["open"] : nil
      new(clock: items.any? { |item| item["anim"] == "clock" },
          robot: items.any? { |item| item["anim"] == "robot" },
          open_enabled: !open.nil?,
          open_frames: open ? (open["cards"] || open["text"]).to_s : OPEN_FRAMES,
          seconds: (doc["ms"].to_i / 1000).clamp(5, 120),
          texts: texts, extras: extras)
    end

    # The form's params: rotation[clock], rotation[texts][0][text], ...
    def self.from_params(params, extras: [])
      p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      texts = (p["texts"] || {}).values_at(*(0...TEXT_LINES).map(&:to_s)).compact
      new(clock: p["clock"], robot: p["robot"], open_enabled: p["open_enabled"],
          open_frames: p["open_frames"], seconds: p["seconds"], texts: texts, extras: extras)
    end

    def items
      list = []
      list << { "anim" => "clock" } if clock
      texts.each do |line|
        words = Marquee.clean_text(line["text"])
        list << { "text" => words, "color" => Marquee.color_value(line["color"]) } unless words.empty?
      end
      list << { "anim" => "robot", "hold" => ROBOT_HOLD } if robot
      list + extras
    end

    def to_panel
      frames = Marquee.clean_frames(open_frames)
      { "ms" => seconds * 1000, "items" => items,
        "open" => open_enabled && frames.present? ? { "cards" => frames, "color" => "#33ff66" } : false }
    end

    def extra_labels
      extras.map { |item| item["anim"] || (item["play"] && "#{item['play']} (stored)") || item["cards"] || "an entry" }
    end

    private

    def normalize_texts(list)
      rows = Array(list).map do |row|
        row = row.to_h.stringify_keys
        { "text" => row["text"].to_s, "color" => Marquee::COLORS.key?(row["color"]) ? row["color"] : "Orange" }
      end
      rows = rows.first(TEXT_LINES)
      rows << { "text" => "", "color" => "Orange" } while rows.size < TEXT_LINES
      rows
    end

    def fits_the_panel
      count = items.size
      errors.add(:base, "Pick at least one thing to show.") if count.zero?
      errors.add(:base, "The sign takes #{MAX_ITEMS} entries at most; this is #{count}.") if count > MAX_ITEMS
    end
  end
end
