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

    # A day with this many new accounts was a bulk load (the 2012 launch and
    # the 2013 imports of the older member list), not people signing up; the
    # sign-up form has never seen more than 5 in a day since.
    BULK_DAY = 15

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

    # Accounts people made themselves (bulk loads left out).
    def signups
      group(self_made, :created_at)
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
      joined = self_made.where(created_at: @period.range)
      {
        "Signed up" => joined.count,
        "Signed a waiver" => joined.where("users.waiver IS NOT NULL OR EXISTS (SELECT 1 FROM contracts WHERE contracts.user_id = users.id)").count,
        "Came to orientation" => joined.where.not(orientation: nil).count,
        "Paid dues" => joined.where("EXISTS (SELECT 1 FROM payments WHERE payments.user_id = users.id)").count,
        "Got a card" => joined.where("EXISTS (SELECT 1 FROM cards WHERE cards.user_id = users.id)").count,
      }
    end

    private

    def self_made
      User.where.not(Arel.sql("(users.created_at)::date IN (SELECT (created_at)::date FROM users GROUP BY 1 HAVING COUNT(*) >= #{BULK_DAY})"))
    end

    def group(scope, column)
      scope.where(column => @period.range).group_by_period(@period.unit, column, range: @period.range).count
    end
  end
end
