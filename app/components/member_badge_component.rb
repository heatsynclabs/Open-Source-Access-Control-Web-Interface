# A person's membership at a glance: their level, coloured by whether their
# dues are current. Uses the same rules as User#member_status_symbol (the old
# coin images): paying levels are current with a payment in the last 60 days.
class MemberBadgeComponent < ViewComponent::Base
  def initialize(user)
    @user = user
  end

  def render?
    level >= 10 || @user.payments_count > 0
  end

  def call
    render ChipComponent.new(label, tone: tone, title: explanation)
  end

  private

  def level
    @user.member_level.to_i
  end

  def paying_level?
    level >= 25
  end

  def label
    return "Former member" if level < 10
    @user.member_level_string.sub(/\s*\(.*\)\z/, "")
  end

  def tone
    return nil if level < 10
    return :info unless paying_level?
    @user.payment_status ? :ok : :warn
  end

  def explanation
    return "Volunteer" if level.between?(10, 24)
    return "No payments recorded" if @user.payments_count.zero?
    return "#{@user.member_level_string}, paid up" if paying_level? && @user.payment_status
    "Last payment #{@user.delinquency / 30} months ago"
  end
end
