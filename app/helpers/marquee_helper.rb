# Wording for the window sign's status. Everything here reads values the sign
# sent, so it tolerates missing or odd ones instead of raising.
module MarqueeHelper
  # "21:00" or "2026-11-25 20:41:00" from the sign, as "9:00 PM"; nil if unreadable.
  def sign_clock(value)
    text = value.to_s
    return nil unless text.match?(/\d{1,2}:\d{2}/)
    Time.zone.parse(text)&.strftime("%-l:%M %p")
  rescue ArgumentError
    nil
  end

  def sign_lab_line(status)
    status = {} unless status.is_a?(Hash)
    return "Lab status not known yet" unless status["valid"]
    return "Lab closed" unless status["on"]
    "Lab open, so Open Hours comes up every other turn"
  end

  def sign_brightness(value)
    Marquee::BRIGHTNESS.key(value.to_i)&.downcase || value.to_s
  end
end
