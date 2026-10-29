module Admin
  # How a computer is named on the Computers page: its owner's name when it
  # has one, otherwise the MAC address, then the owner's note in brackets.
  # Signed-in members see the details (MAC, IP, hours here) on hover.
  class MacLabelComponent < ViewComponent::Base
    def initialize(mac:, details: nil)
      @mac = mac
      @details = details
    end

    def call
      tag.span(class: "mac-label", title: @details.presence) do
        safe_join([
          tag.span(@mac.user ? @mac.user.name : @mac.mac, class: ("mono" unless @mac.user)),
          (tag.span(@mac.note, class: "muted small") if @mac.note.present?),
        ].compact, " ")
      end
    end
  end
end
