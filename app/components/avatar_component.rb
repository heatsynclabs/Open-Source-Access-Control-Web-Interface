# A round avatar: the person's initials on a colour derived from their name,
# with their Gravatar on top when they have one. Gravatar answers 404 for
# people without one (d=404) and the image then removes itself.
#
# Pass gravatar_hash when the email is deliberately not loaded (the active
# cardholders list computes the hash in SQL).
class AvatarComponent < ViewComponent::Base
  def initialize(name:, email: nil, gravatar_hash: nil, size: 40)
    @name = name.to_s
    @hash = gravatar_hash || Digest::MD5.hexdigest(email.to_s.strip.downcase)
    @size = size
  end

  def call
    tag.span(class: "avatar", style: "--s:#{@size}px;--h:#{hue}", "aria-hidden": "true") do
      tag.span(initials) + gravatar
    end
  end

  private

  def initials
    @name.split(/\s+/).reject(&:blank?).first(2).map { |word| word[0] }.join.upcase
  end

  # The same name always gets the same colour.
  def hue
    @name.each_char.reduce(7) { |hue, char| (hue * 31 + char.ord) % 360 }
  end

  def gravatar
    tag.img(src: "https://www.gravatar.com/avatar/#{@hash}?s=#{@size * 2}&d=404",
            alt: "", loading: "lazy", onerror: "this.remove()")
  end
end
