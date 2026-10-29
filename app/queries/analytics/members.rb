module Analytics
  # Who joins, who stays, who pays: counts only, never names.
  class Members
    # The same "paid up" rule the bylaws thresholds use: a payment in 60 days.
    PAID_UP_DAYS = 60

    LEVEL_BANDS = [
      ["Plus", 100..],
      ["Basic", 50...100],
      ["Associate", 25...50],
      ["Volunteer", 10...25],
    ].freeze

    def initialize(period)
      @period = period
    end

    def paid_up_count
      Payment.where("date > ?", PAID_UP_DAYS.days.ago.to_date).distinct.count(:user_id)
    end

    def active_count
      User.active.count
    end

    def cardholder_count
      Card.where(card_permissions: 1).where.not(user_id: nil).distinct.count(:user_id)
    end

    def new_this_month_count
      User.where(created_at: Time.zone.now.beginning_of_month..).count
    end

    def signups
      group(User, :created_at)
    end

    def orientations
      group(User, :orientation)
    end

    def waivers_signed
      group(Contract, :signed_at)
    end

    def certifications_granted
      group(UserCertification, :created_at)
    end

    # Members on each level right now.
    def level_mix
      counts = User.active.group(:member_level).count
      LEVEL_BANDS.to_h do |name, levels|
        [name, counts.sum { |level, count| levels.cover?(level.to_i) ? count : 0 }]
      end
    end

    def top_certifications(limit = 8)
      UserCertification.joins(:certification).where(created_at: @period.range)
        .group("certifications.name").count.sort_by { |_name, count| -count }.first(limit)
    end

    # Of the people who signed up in the period, how many reached each step.
    def funnel
      joined = User.where(created_at: @period.range)
      {
        "Signed up" => joined.count,
        "Signed a waiver" => joined.where("users.waiver IS NOT NULL OR EXISTS (SELECT 1 FROM contracts WHERE contracts.user_id = users.id)").count,
        "Came to orientation" => joined.where.not(orientation: nil).count,
        "Paid dues" => joined.where("EXISTS (SELECT 1 FROM payments WHERE payments.user_id = users.id)").count,
        "Got a card" => joined.where("EXISTS (SELECT 1 FROM cards WHERE cards.user_id = users.id)").count,
      }
    end

    # Payers grouped by the month of their first payment, and the share of
    # each group still paying 3, 6 and 12 months later (nil until that
    # month has come).
    def payer_retention
      months_paid = Hash.new { |hash, user| hash[user] = Set.new }
      Payment.where.not(user_id: nil).pluck(:user_id, :date).each do |user_id, date|
        months_paid[user_id] << month_index(date) if date
      end

      cohorts = months_paid.group_by { |_user, months| months.min }
      first_month = month_index(@period.starts_at.to_date)
      this_month = month_index(Date.current)
      cohorts.select { |month, _payers| month >= first_month }.sort.map do |month, payers|
        still_paying = [3, 6, 12].map do |later|
          next nil if month + later > this_month
          payers.count { |_user, months| months.include?(month + later) } * 100.0 / payers.size
        end
        [Date.new(month / 12, month % 12 + 1, 1), payers.size, *still_paying]
      end
    end

    private

    def group(scope, column)
      scope.where(column => @period.range).group_by_period(@period.unit, column, range: @period.range).count
    end

    def month_index(date)
      date.year * 12 + date.month - 1
    end
  end
end
