# One quiet line under the unlocked front door: who unlocked it and how long
# ago. unlock is a DoorActivity::Unlock, or nil. With nobody to name it still
# says when; with no unlock at all it renders nothing.
class UnlockedByComponent < ViewComponent::Base
  def initialize(unlock, now: Time.zone.now)
    @unlock = unlock
    @now = now
  end

  def render?
    @unlock.present?
  end

  def call
    tag.p(class: "unlocked-by") do
      safe_join([avatar, tag.span(words), " ", when_tag].compact)
    end
  end

  private

  def person
    @unlock.who
  end

  def avatar
    render AvatarComponent.new(name: person.name, email: person.email, size: 20) if person
  end

  def words
    person ? safe_join(["Unlocked by ", tag.strong(person.short_name)]) : "Unlocked"
  end

  def when_tag
    tag.time(ago, datetime: @unlock.at.iso8601, title: @unlock.at.strftime("%b %-d, %-l:%M %p"))
  end

  def ago
    minutes = ((@now - @unlock.at) / 60).floor
    return "just now" if minutes < 1
    return "#{minutes} min ago" if minutes < 60
    "#{minutes / 60} h ago"
  end
end
