module DeviseHelper
  # Restores devise_error_messages!, which Devise removed in 4.2+ and the
  # bundled devise views (registrations, passwords, unlocks, confirmations)
  # still call. Renders the resource's validation errors as the same
  # #error_explanation block the rest of the app uses, so it picks up the
  # GANTRY theme styling. Presentation only, no behavior change.
  def devise_error_messages!
    return "" if resource.errors.empty?

    messages = resource.errors.full_messages.map { |message| content_tag(:li, message) }.join
    sentence = I18n.t("errors.messages.not_saved",
                      count: resource.errors.count,
                      resource: resource.class.model_name.human.downcase)

    html = <<-HTML
      <div id="error_explanation">
        <h2>#{sentence}</h2>
        <ul>#{messages}</ul>
      </div>
    HTML

    html.html_safe
  end

  def devise_error_messages?
    !resource.errors.empty?
  end
end
