# The top of a page: a small eyebrow line, the title, an optional lead
# sentence, and buttons on the right. Also sets the browser tab title.
#
#   <%= render PageHeaderComponent.new(eyebrow: "Admin", title: "Cards") do |header| %>
#     <% header.with_action { link_to "New card", new_card_path, class: "btn" } %>
#   <% end %>
class PageHeaderComponent < ViewComponent::Base
  renders_many :actions

  def initialize(title:, eyebrow: nil, lead: nil, eyebrow_path: nil)
    @title = title
    @eyebrow = eyebrow
    @eyebrow_path = eyebrow_path
    @lead = lead
  end

  def before_render
    helpers.content_for(:title, @title) unless helpers.content_for?(:title)
  end
end
