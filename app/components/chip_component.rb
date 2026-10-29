# A small uppercase status label. tone: :ok, :warn, :err, :info, :fill or nil.
class ChipComponent < ViewComponent::Base
  def initialize(text, tone: nil, dot: false, title: nil)
    @text = text
    @tone = tone
    @dot = dot
    @title = title
  end

  def call
    tag.span(@text, class: ["chip", @tone, ("dot" if @dot)], title: @title)
  end
end
