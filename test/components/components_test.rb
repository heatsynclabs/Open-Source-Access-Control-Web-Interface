require "test_helper"
require "view_component/test_case"

class ComponentsTest < ViewComponent::TestCase
  # render_inline returns the rendered HTML as a Nokogiri fragment.
  def assert_has(html, selector, text: nil, count: nil)
    found = html.css(selector)
    found = found.select { |node| node.text.include?(text) } if text
    count ? assert_equal(count, found.size, selector) : assert(found.any?, "expected #{selector}")
  end

  def assert_none(html, selector)
    assert html.css(selector).empty?, "expected no #{selector}"
  end

  # A saved member: the badge reads payments from the database, as on the site.
  def user_with(level:, paid_days_ago: nil)
    user = User.new(name: "Grace Hopper", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password", member_level: level,
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    Payment.create!(user: user, date: Date.current - paid_days_ago, amount: level) if paid_days_ago
    user
  end

  test "a paid-up member's badge names their level in the ok tone" do
    html = render_inline MemberBadgeComponent.new(user_with(level: 50, paid_days_ago: 10))
    assert_has html, "span.chip.ok", text: "Basic"
  end

  test "an overdue member's badge warns and says when they last paid" do
    html = render_inline MemberBadgeComponent.new(user_with(level: 50, paid_days_ago: 95))
    assert_has html, "span.chip.warn[title='Last payment 3 months ago']"
  end

  test "people who never joined get no badge" do
    html = render_inline MemberBadgeComponent.new(user_with(level: 0))
    assert_none html, "span.chip"
  end

  test "the avatar shows initials under a Gravatar that is transparent when missing" do
    html = render_inline AvatarComponent.new(name: "Ada Lovelace", email: "ada@example.invalid", size: 32)
    assert_has html, "span.avatar span", text: "AL"
    assert_has html, "img[src*='d=blank']"
  end

  test "form errors render only for an invalid record" do
    card = Card.new
    card.valid?
    html = render_inline FormErrorsComponent.new(card)
    assert_has html, ".form-errors li"
    html = render_inline FormErrorsComponent.new(Card.new(card_number: "1", card_permissions: 1, user_id: 1))
    assert_none html, ".form-errors"
  end

  test "the week card lists events by day and shows open hours as a line" do
    day = Date.current
    event = ->(title, hour) do
      LabCalendar::Event.new(id: title, title: title, description: "", location: "", starts_at: day.in_time_zone + hour.hours,
                             ends_at: day.in_time_zone + (hour + 2).hours, all_day: false, repeating: false)
    end
    html = render_inline Calendar::WeekComponent.new(days: day..(day + 6), events: [event.call("Open Hours", 18), event.call("Laser Meetup", 19)])
    assert_has html, ".week-day.today a.event", text: "Laser Meetup"
    assert_has html, ".week-day.today .open-line", text: "Open 6 to 8pm"
    assert_has html, "dialog.event-dialog", count: 1
  end
end
