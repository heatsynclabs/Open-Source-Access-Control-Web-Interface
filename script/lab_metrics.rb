# Loads LabMetric from the file the ops folder builds from its data CSVs
# (data/scripts/lab_metrics_export.py; docs/analytics.md has the steps).
#
#   bundle exec rails runner script/lab_metrics.rb load lab-metrics-2026-11-20.json
#
# Replaces the rows of every metric in the file in one transaction, so it can
# be rerun; metrics not in the file are left alone. The file holds counts and
# totals only.
require "json"

mode, path = ARGV
abort "usage: load lab-metrics.json" unless mode == "load" && path
abort "run bundle exec rails db:migrate first (lab_metrics is missing)" unless LabMetric.available?

metrics = JSON.parse(File.read(path)).fetch("metrics")
abort "refusing: no metrics in the file" unless metrics.is_a?(Array) && metrics.any?
now = Time.current
records = metrics.map do |row|
  record = LabMetric.new(row.slice("key", "label", "period", "starts_on", "value", "source"))
  abort "refusing: #{row.inspect} is not valid (#{record.errors.full_messages.to_sentence})" unless record.valid?
  record.attributes.except("id").merge("created_at" => now, "updated_at" => now)
end
keys = records.map { |record| record["key"] }.uniq
LabMetric.transaction do
  LabMetric.where(key: keys).delete_all
  LabMetric.insert_all!(records)
end
Rails.cache.delete_matched("analytics") rescue nil
puts "loaded #{records.size} rows for #{keys.size} metrics: #{keys.join(", ")}"
