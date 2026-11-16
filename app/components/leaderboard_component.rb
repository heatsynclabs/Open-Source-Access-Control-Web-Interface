# A ranked list of members: rank, avatar, short name with an optional detail
# line, the figure on the right, and a bar for their share of the leader's.
# rows respond to user and rank. score gives the number the bar is drawn
# from, figure the text on the right, detail an optional small line.
#
#   render LeaderboardComponent.new(rows: rows, me: current_user, empty: "Nobody yet.",
#     score: ->(row) { row.days }, figure: ->(row) { "#{row.days} days" })
class LeaderboardComponent < ViewComponent::Base
  def initialize(rows:, score:, figure:, empty:, detail: nil, me: nil)
    @rows = rows
    @score = score
    @figure = figure
    @detail = detail
    @empty = empty
    @me = me
  end

  def call
    return render(EmptyStateComponent.new(@empty)) if @rows.empty?
    most = @rows.map { |row| @score.call(row) }.max.to_f
    tag.ol(class: "leaderboard") { safe_join(@rows.map { |row| item(row, most) }) }
  end

  private

  def item(row, most)
    share = most.positive? ? (@score.call(row) / most).round(3) : 0
    tag.li(class: [("first" if row.rank == 1), ("me" if @me && row.user.id == @me.id)]) do
      safe_join([
        tag.span(row.rank, class: "rank"),
        render(AvatarComponent.new(name: row.user.name, email: row.user.email, size: 28)),
        tag.span(class: "person-name") do
          safe_join([tag.span(row.user.short_name, class: "name"), (tag.small(@detail.call(row)) if @detail)].compact)
        end,
        tag.span(@figure.call(row), class: "value"),
        tag.span(tag.span(style: "--v: #{share}"), class: "bar", role: "presentation"),
      ])
    end
  end
end
