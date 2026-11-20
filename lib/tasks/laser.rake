namespace :laser do
  desc "Read the laser log sheet and rebuild laser_jobs (nightly; see docs/laser.md)"
  task sync: :environment do
    abort "run bundle exec rails db:migrate first (laser_jobs is missing)" unless LaserJob.available?
    tally = LaserLog::Sync.new.run
    puts "laser sync: #{tally[:kept]} jobs kept of #{tally[:read]} rows (#{tally[:skipped]} without a readable date)"
    Laser::Model.summary # worked out now, so the first visitor does not wait
  rescue LaserLog::Error => e
    abort "laser sync: #{e.message}; the jobs already held are unchanged"
  end
end
