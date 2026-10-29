# One number with its label, for the row of tiles at the top of a page.
# tone: :headline for the main figure, :alert for something needing attention.
class StatTileComponent < ViewComponent::Base
  def initialize(value:, label:, sub: nil, tone: nil, href: nil)
    @value = value
    @label = label
    @sub = sub
    @tone = tone
    @href = href
  end

  def call
    body = safe_join([
      tag.div(@value, class: "num"),
      tag.div(@label, class: "label"),
      (tag.div(@sub, class: "sub") if @sub),
    ].compact)
    body = link_to(body, @href, class: "tile-link") if @href
    tag.div(body, class: ["tile", @tone])
  end
end
