# Counts and totals about the lab gathered from records the site does not
# hold: old backups, PayPal exports, utility bills, the mailing list, the old
# wiki and the tax returns. They are worked out in the ops folder (data/,
# one script per source) and loaded with script/lab_metrics.rb; the
# analytics page's "Over the years" tab shows them (Analytics::History).
#
# One row per metric (key), breakdown (label, "" for none) and period
# (month, year, or a "total" dated by the copy it was read from). A null
# value means fewer than 5: the small-cell rule the ops data follows.
class LabMetric < ActiveRecord::Base
  PERIODS = %w[month year total].freeze

  validates :key, :period, :starts_on, :source, presence: true
  validates :period, inclusion: { in: PERIODS }

  # Deploys do not run migrations; until the table exists the tab says the
  # figures have not been loaded.
  def self.available?
    connection.table_exists?(table_name)
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
