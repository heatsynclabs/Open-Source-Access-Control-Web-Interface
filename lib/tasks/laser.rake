namespace :laser do
  desc "Rebuild laser_jobs from the 2013 to 2020 log file and the laser log sheet (nightly; see docs/laser.md)"
  task sync: :environment do
    abort "run bundle exec rails db:migrate first (laser_jobs is missing)" unless LaserJob.available?
    puts "laser sync: #{LaserLog::Archive.new.load!} jobs from the earlier log (2013 to 2020)"
    tally = LaserLog::Sync.new.run
    puts "laser sync: #{tally[:kept]} jobs kept of #{tally[:read]} rows (#{tally[:skipped]} without a readable date)"
    Laser::Model.summary # worked out now, so the first visitor does not wait
  rescue LaserLog::Error => e
    abort "laser sync: #{e.message}; the jobs already held are unchanged"
  end
end
