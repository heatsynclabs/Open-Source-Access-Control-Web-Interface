module Analytics
  # Dues coming in. Amounts are what was recorded, whatever the source.
  class Payments
    TIERS = { 25 => "$25", 50 => "$50", 100 => "$100" }.freeze

    def initialize(period)
      @period = period
    end

    def dues_total
      in_period.sum(:amount).to_f
    end

    def average_payment
      in_period.average(:amount).to_f.round(2)
    end

    def dues_by_period
      in_period.group_by_period(@period.unit, :date, range: @period.dates).sum(:amount).transform_values(&:to_f)
    end

    def payers_by_period
      in_period.group_by_period(@period.unit, :date, range: @period.dates).distinct.count(:user_id)
    end

    # How many payments were at each tier price, with everything else as Other.
    def tier_mix
      in_period.group(:amount).count.each_with_object(Hash.new(0)) do |(amount, count), mix|
        mix[TIERS.fetch(amount.to_i, "Other")] += count
      end.sort_by { |tier, _count| TIERS.values.index(tier) || TIERS.size }.to_h
    end

    # How active members say they pay.
    def methods
      User.active.group(:payment_method).count
        .transform_keys { |method| method.presence || "Not set" }
        .sort_by { |_method, count| -count }.to_h
    end

    # PayPal rows that look like dues but are not linked to anyone yet (the
    # same rule as the PayPal page's "needs review" list).
    def paypal_waiting_count
      PaypalCsv.where(payment_id: nil).order(id: :desc).limit(1000).count(&:incoming_payment?)
    end

    private

    def in_period
      Payment.where(date: @period.dates)
    end
  end
end
