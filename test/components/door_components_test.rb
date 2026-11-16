require "test_helper"
require "view_component/test_case"

class DoorComponentsTest < ViewComponent::TestCase
  NOW = Time.zone.local(2026, 11, 15, 20, 0)

  def person(name = "Ada Lovelace", id: 7)
    User.new(id: id, name: name, email: "ada@example.invalid")
  end

  def unlock(who: person, ago: 12.minutes)
    DoorActivity::Unlock.new(who: who, at: NOW - ago)
  end

  # The words of a line, without the avatar's initials.
  def words(html, selector)
    html.css(".avatar").each(&:remove)
    html.css(selector).text.squish
  end

  test "names who unlocked the door by first name and initial, with how long ago" do
    html = render_inline UnlockedByComponent.new(unlock, now: NOW)
    assert html.css(".unlocked-by .avatar").any?
    assert html.css("time[datetime]").any?
    assert_equal "Unlocked by Ada L. 12 min ago", words(html, "p.unlocked-by")
  end

  test "says just Unlocked when nobody can be named" do
    html = render_inline UnlockedByComponent.new(unlock(who: nil, ago: 10.seconds), now: NOW)
    assert_equal "Unlocked just now", words(html, "p.unlocked-by")
    assert html.css(".avatar").empty?
  end

  test "counts hours once past an hour" do
    html = render_inline UnlockedByComponent.new(unlock(ago: 3.hours + 5.minutes), now: NOW)
    assert_equal "Unlocked by Ada L. 3 h ago", words(html, "p.unlocked-by")
  end

  test "renders nothing without an unlock" do
    assert_equal "", render_inline(UnlockedByComponent.new(nil, now: NOW)).to_html.strip
  end

  test "an unlocked door tile carries the line and a locked one does not" do
    html = render_inline DoorTileComponent.new(name: "Front door", locked: false, open_command: "open-front", unlocked_by: unlock)
    assert html.css(".door.unlocked .unlocked-by").any?
    html = render_inline DoorTileComponent.new(name: "Front door", locked: true, open_command: "open-front", unlocked_by: unlock)
    assert html.css(".unlocked-by").empty?
    html = render_inline DoorTileComponent.new(name: "Rear door", locked: true, open_command: "open-rear")
    assert html.css(".door.locked").any?
  end

  test "the leaderboard ranks people, marks the leader and you, and shows details" do
    me = person("Grace Hopper", id: 8)
    rows = [DoorActivity::Row.new(user: person, rank: 1, hours: 4.5, shifts: 2, opened: 3, locked: 2),
            DoorActivity::Row.new(user: me, rank: 2, hours: 0.0, shifts: 0, opened: 1, locked: 0)]
    html = render_inline LeaderboardComponent.new(rows: rows, me: me, empty: "none",
             score: ->(row) { row.hours }, figure: ->(row) { "#{row.hours} h" }, detail: ->(row) { "opened #{row.opened}" })
    assert_equal ["Ada L.", "Grace H."], html.css("li .name").map(&:text)
    assert_equal "1", html.css("li.first .rank").text
    assert_equal "Grace H.", html.css("li.me .name").text
    assert_equal "4.5 h", html.css("li.first .value").text
    assert_equal "opened 3", html.css("li.first small").text
    assert_equal ["--v: 1.0", "--v: 0.0"], html.css(".bar span").map { |bar| bar["style"] }
  end

  test "a board where nobody has hours yet draws empty bars" do
    rows = [DoorActivity::Row.new(user: person, rank: 1, hours: 0.0, shifts: 0, opened: 1, locked: 0)]
    html = render_inline LeaderboardComponent.new(rows: rows, empty: "none", score: ->(row) { row.hours }, figure: ->(row) { "#{row.hours} h" })
    assert_equal "--v: 0", html.css(".bar span").first["style"]
  end

  test "an empty leaderboard says so" do
    html = render_inline LeaderboardComponent.new(rows: [], score: ->(row) { 0 }, figure: ->(row) { "" }, empty: "Nobody yet.")
    assert_equal "Nobody yet.", html.css("p.empty").text
  end
end
