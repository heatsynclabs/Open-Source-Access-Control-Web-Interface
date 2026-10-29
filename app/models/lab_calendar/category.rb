module LabCalendar
  # What kind of event this is, for its colour and icon. The rules and their
  # order match heatsynclabs.org (new-hsl src/utils/eventCategory.ts and
  # knownEvents.ts), so an event looks the same on both sites.
  class Category < Data.define(:key, :label, :default_icon)
    GROUP_WORDS = ["meetup", "study group", "users group", "chapter meeting", "chapter", "book club", "society"].freeze

    # Known recurring events get their own icon (Lucide names). First match wins.
    KNOWN_EVENT_ICONS = {
      "caffeine" => "coffee", "craft night" => "scissors", "sewing" => "scissors", "jewelry" => "gem",
      "lego" => "blocks", "3d-printer" => "printer", "prusa" => "printer", "laser meetup" => "zap",
      "laser cutter" => "zap", "freecad" => "pencil-ruler", "arduino" => "cpu", "group programming" => "code",
      "leetcode" => "code", "phxjs" => "code", "phoenix gdg" => "globe", "owasp" => "shield", "book club" => "book-open",
      "d&d" => "dices", "young makers" => "users", "photo meetup" => "camera", "browser wars" => "globe",
      "lock picking" => "lock", "hack your hackerspace" => "wrench",
    }.freeze

    ALL = [
      new(key: "class", label: "Workshop", default_icon: "graduation-cap"),
      new(key: "open", label: "Open hours", default_icon: "clock"),
      new(key: "hack", label: "HYH", default_icon: "wrench"),
      new(key: "group", label: "Group", default_icon: "users"),
      new(key: "recurring", label: "Recurring", default_icon: "repeat"),
      new(key: "default", label: "Event", default_icon: "calendar"),
    ].freeze

    def self.all
      ALL
    end

    def self.find(key)
      all.find { |category| category.key == key.to_s }
    end

    def self.for(event)
      title = event.title.downcase
      key =
        if event.registration_required? then "class"
        elsif title.include?("open hours") || title.include?("member hours") then "open"
        elsif title.include?("hack your hackerspace") then "hack"
        elsif GROUP_WORDS.any? { |word| title.include?(word) } then "group"
        elsif event.repeating then "recurring"
        else "default"
        end
      find(key)
    end

    def self.icon_for(event)
      title = event.title.downcase
      KNOWN_EVENT_ICONS.find { |match, _icon| title.include?(match) }&.last || event.category.default_icon
    end
  end
end
