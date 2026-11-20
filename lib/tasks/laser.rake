namespace :laser do
  desc "Read the laser log sheet and rebuild laser_jobs, loading the 2013 to 2020 log if needed (nightly; see docs/laser.md)"
  task sync: :environment do
    abort "run bundle exec rails db:migrate first (laser_jobs is missing)" unless LaserJob.available?
    archive = LaserLog::Archive.new
    puts "laser sync: earlier log loaded, #{archive.load!} jobs (2013 to 2020)" unless archive.loaded?
    tally = LaserLog::Sync.new.run
    puts "laser sync: #{tally[:kept]} jobs kept of #{tally[:read]} rows (#{tally[:skipped]} without a readable date)"
    Laser::Model.summary # worked out now, so the first visitor does not wait
  rescue LaserLog::Error => e
    abort "laser sync: #{e.message}; the jobs already held are unchanged"
  end
end
