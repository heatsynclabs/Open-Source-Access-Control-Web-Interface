# What a list says when it has nothing in it.
class EmptyStateComponent < ViewComponent::Base
  def initialize(text)
    @text = text
  end

  def call
    tag.p(@text, class: "empty")
  end
end
