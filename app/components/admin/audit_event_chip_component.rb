module Admin
  # The event type on the audit log as a chip, tinted by what it touched:
  # member records, certifications or payments.
  class AuditEventChipComponent < ViewComponent::Base
    TONES = { "user" => :info, "cert" => :ok, "payment" => :warn }.freeze

    def initialize(event_type)
      @event_type = event_type.to_s
    end

    def call
      render ChipComponent.new(@event_type.tr("_", " "), tone: TONES[@event_type.split("_").first])
    end
  end
end
