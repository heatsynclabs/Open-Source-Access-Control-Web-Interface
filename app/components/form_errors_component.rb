# The list of validation errors above a form. Renders nothing when the record
# is valid.
class FormErrorsComponent < ViewComponent::Base
  def initialize(record)
    @record = record
  end

  def render?
    @record.errors.any?
  end

  def call
    count = @record.errors.count
    tag.div(class: "form-errors", role: "alert") do
      tag.h2("#{count} #{'problem'.pluralize(count)} to fix before saving") +
        tag.ul(safe_join(@record.errors.full_messages.map { |message| tag.li(message) }))
    end
  end
end
