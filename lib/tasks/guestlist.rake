namespace :guestlist do
  desc "Read new and recent classes from guestlist.co's public pages (nightly; see docs/analytics.md)"
  task sync: :environment do
    abort "run bin/rails db:migrate first (ticketed_events is missing)" unless TicketedEvent.available?
    tally = Guestlist::Sync.new.run
    puts "guestlist sync: #{tally.map { |outcome, count| "#{count} #{outcome}" }.join(", ").presence || "nothing to read"}"
    exit 1 if tally[:failed].positive? && tally[:read].zero?
  end
end
