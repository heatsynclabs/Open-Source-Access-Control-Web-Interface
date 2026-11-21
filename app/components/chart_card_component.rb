# A titled card around one chart, with the numbers behind it in a table that
# opens underneath (for screen readers, and for anyone who wants the exact
# values). The first chart card on a page loads the chart scripts.
#
#   <%= render ChartCardComponent.new(title: "Signups", rows: data, columns: ["Month", "Signups"]) do %>
#     <%= column_chart data %>
#   <% end %>
#
# more: a link to a fuller page about the same thing ("Deep dive").
class ChartCardComponent < ViewComponent::Base
  def initialize(title:, rows: nil, columns: nil, note: nil, more: nil)
    @title = title
    @rows = rows
    @columns = columns
    @note = note
    @more = more
  end

  def before_render
    helpers.load_chart_scripts
  end
end
