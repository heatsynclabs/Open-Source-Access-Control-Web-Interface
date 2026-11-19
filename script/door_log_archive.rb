# Loads DoorLogArchive: the granted swipes and remote commands of the years
# the live door_logs table does not hold (September 2012 to October 2020),
# for the analytics page.
#
#   bin/rails runner script/door_log_archive.rb load IN.csv.gz
#
# On production, after bin/rails db:migrate. IN is a gzip CSV with the
# header key,data,created_at (UTC), built off the server from the fullest
# door log (the ops Omnibus, door-logs/). Replaces the table's rows in one
# transaction, so it can be rerun. Remote command rows hold member ids:
# keep the file out of git.
require "csv"
require "zlib"

mode, path = ARGV
abort "usage: load IN.csv.gz" unless mode == "load" && path
abort "run bin/rails db:migrate first (door_log_archives is missing)" unless DoorLogArchive.available?

LIVE_LOG_STARTS = Time.utc(2022, 7, 30)
rows = 0
conn = DoorLogArchive.connection
DoorLogArchive.transaction do
  DoorLogArchive.delete_all
  raw = conn.raw_connection
  raw.copy_data("COPY door_log_archives (key, data, created_at) FROM STDIN WITH (FORMAT csv)") do
    Zlib::GzipReader.open(path) do |gz|
      CSV.new(gz, headers: true).each do |row|
        key, data, at = row.values_at("key", "data", "created_at")
        abort "refusing: #{key.inspect} is not a swipe or a remote command" unless key == "G" || key.start_with?("rem_", "api_rem_")
        abort "refusing: a row from #{at} overlaps the live log" if Time.find_zone("UTC").parse(at) >= LIVE_LOG_STARTS
        raw.put_copy_data(CSV.generate_line([key, Integer(data), at]))
        rows += 1
      end
    end
  end
end
Rails.cache.delete_matched("analytics") rescue nil
from, to = DoorLogArchive.pick(Arel.sql("MIN(created_at)"), Arel.sql("MAX(created_at)"))
puts "loaded #{rows} rows, #{from} to #{to}"
