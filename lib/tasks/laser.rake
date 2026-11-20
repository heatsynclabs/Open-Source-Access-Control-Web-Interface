namespace :laser do
  desc "Rebuild laser_jobs from both lasers' log sheets (nightly; see docs/laser.md)"
  task sync: :environment do
    abort "run bundle exec rails db:migrate first (laser_jobs is missing)" unless LaserJob.available?
    failed = false
    LaserLog::Sync.new.run.each do |sheet, t|
      name = "#{LaserJob::MACHINES[sheet.machine]} #{sheet.source}"
      if t[:error]
        failed = true
        puts "laser sync: #{name}: #{t[:error]}; its jobs are unchanged"
      else
        puts "laser sync: #{name}: #{t[:kept]} jobs kept of #{t[:read]} rows"
      end
    end
    LaserJob::MACHINES.each_key { |machine| Laser::Model.summary(machine) } # worked out now, so the first visitor does not wait
    abort "laser sync: a sheet was not read" if failed
  end
end
