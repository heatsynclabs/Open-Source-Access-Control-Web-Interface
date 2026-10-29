# One door's lock state, with an "open for 5 seconds" button for people who
# may work the doors remotely. locked is true, false, or nil when the board
# has not reported yet.
class DoorTileComponent < ViewComponent::Base
  def initialize(name:, locked:, open_command:, can_control: false)
    @name = name
    @locked = locked
    @open_command = open_command
    @can_control = can_control
  end

  def call
    tag.div(class: ["door", state_class]) do
      safe_join([
        tag.span(@name, class: "eyebrow"),
        tag.span(state_label, class: "state"),
        (open_button if @can_control),
      ].compact)
    end
  end

  private

  def state_class
    return "unknown" if @locked.nil?
    @locked ? "locked" : "unlocked"
  end

  def state_label
    return "Unknown" if @locked.nil?
    @locked ? "Locked" : "Unlocked"
  end

  # Posts the same command the remote access page sends.
  def open_button
    tag.div(class: "actions") do
      button_to "Open for 5 seconds", helpers.space_api_access_path, params: { cmd: @open_command }, class: "btn primary small"
    end
  end
end
