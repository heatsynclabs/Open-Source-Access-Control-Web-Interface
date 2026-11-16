# Development-only sample members so the roster looks populated.
# Idempotent: existing accounts (matched by email) are left untouched,
# so re-running never duplicates. Never runs outside development.
def seed_dev_members!
  return unless Rails.env.development?

  admin_id = User.find_by(email: "admin@example.com")&.id

  skills  = ["soldering, electronics", "woodworking, CNC", "sewing, textiles",
             "3D printing", "laser cutting", "welding, metalwork",
             "programming, embedded", "screen printing"]
  sources = ["a friend", "a meetup", "the website", "a class", "walk-in", "social media"]

  members = [
    { name: "Ada Lovelace",      email: "ada@example.com",      level: 100, oriented: true, instructor: true, card: true, waiver: true, pay: true, zip: "85201" },
    { name: "Grace Hopper",      email: "grace@example.com",    level: 50,  oriented: true, instructor: true, card: true,              pay: true, zip: "85203" },
    { name: "Nikola Tesla",      email: "nikola@example.com",   level: 100, oriented: true,                   card: true, waiver: true, pay: true, zip: "85281" },
    { name: "Hedy Lamarr",       email: "hedy@example.com",     level: 25,  oriented: true,                   card: true,              pay: true, zip: "85210" },
    { name: "Claude Shannon",    email: "shannon@example.com",  level: 50,  oriented: true,                                            pay: true, zip: "85202" },
    { name: "Rosalind Franklin", email: "rosalind@example.com", level: 25,  oriented: true,                   card: true,              pay: true, zip: "85224" },
    { name: "Alan Turing",       email: "alan@example.com",     level: 100, oriented: true,                   card: true,              pay: true, zip: "85233" },
    { name: "Katherine Johnson", email: "katherine@example.com",level: 50,  oriented: true,                                            pay: true, zip: "85204" },
    { name: "Margaret Hamilton", email: "margaret@example.com", level: 25,                                                             pay: true, zip: "85212" },
    { name: "Shuri Okoye",       email: "shuri@example.com",    level: 10,  oriented: true,                   card: true,                         zip: "85282" },
    { name: "Carl Sagan",        email: "carl@example.com",     level: 10,                                                                        zip: "85209" },
    { name: "Mae Jemison",       email: "mae@example.com",      level: 50,  oriented: true,                               waiver: true, pay: true, zip: "85215" },
    { name: "Vikram Prakash",    email: "vikram@example.com",   level: 25,  hidden: true,                                                         zip: "85206" },
    { name: "Lena Soto",         email: "lena@example.com",     level: 0,                                                                         zip: "85225" },
  ]

  created = 0
  members.each_with_index do |m, i|
    next if User.exists?(email: m[:email])

    user = User.new(
      name:             m[:name],
      email:            m[:email],
      password:         "password",
      password_confirmation: "password",
      postal_code:      m[:zip],
      member_level:     m[:level],
      instructor:       !!m[:instructor],
      hidden:           !!m[:hidden],
      current_skills:   skills[i % skills.length],
      desired_skills:   skills[(i + 3) % skills.length],
      marketing_source: sources[i % sources.length],
      orientation:      (m[:oriented] ? (Date.today - (30 + i)) : nil)
    )
    user.save!
    created += 1

    Card.create!(user_id: user.id, card_number: format("%08x", 0x5a1000 + i * 7919), card_permissions: 1) if m[:card]

    if m[:waiver]
      first, last = m[:name].split(" ", 2)
      Contract.create!(user_id: user.id, first_name: first, last_name: last,
                       signed_at: (Time.now - (40 + i).days), created_by_id: admin_id)
    end

    Payment.create!(user_id: user.id, date: (Date.today - (i * 3)), amount: m[:level], created_by: admin_id) if m[:pay]
  end

  puts "Seeded #{created} dev members."
end

# Development-only door history for the "who unlocked it" line and the door
# leaderboard: remote unlocks and locks by seeded members, the after-hours
# auto-lock, card swipes (g/G pairs, as the board logs them), and the front
# door unlocked right now. Runs once, only when the door log is empty.
def seed_dev_door_events!
  return unless Rails.env.development?
  return if DoorLog.exists?

  people = User.where(email: %w[ada@example.com grace@example.com nikola@example.com hedy@example.com
                                alan@example.com rosalind@example.com shuri@example.com vikram@example.com])
               .index_by { |user| user.email.split("@").first }
  return if people.size < 8

  auto_lock = DoorLogsHelper::AUTOMATIC_LOCK_ID
  half = DoorLogsHelper::CARD_HALF
  rng = Random.new(42)
  now = Time.zone.now
  log = ->(key, data, at) { DoorLog.create!(key: key, data: data, created_at: at, updated_at: at) }
  status = ->(front_locked, at) do
    log.("door_1_locked", front_locked ? 1 : 0, at + 2.seconds)
    log.("door_2_locked", 1, at + 2.seconds)
  end
  swipe = ->(user, at) do
    number = user.cards.first&.card_number.to_s.to_i(16)
    next if number.zero?
    log.("g", number / half, at)
    log.("G", number % half, at + 1.second)
  end

  # Who tends to open up: weights make a clear leader without a runaway.
  openers = %w[ada ada ada grace grace nikola alan alan hedy rosalind shuri].map { |key| people[key] }
  swipers = %w[ada grace nikola hedy rosalind alan shuri].map { |key| people[key] }

  (1..75).reverse_each do |days_ago|
    day = (now - days_ago.days).beginning_of_day
    next if rng.rand < 0.25 # some days nobody opens up

    opener = openers[rng.rand(openers.size)]
    opened = day + (16 + rng.rand(3)).hours + rng.rand(50).minutes
    log.(rng.rand < 0.3 ? "api_rem_u=1" : "rem_u=1", opener.id, opened)
    status.(false, opened)

    # Someone else unlocks again while it is already open (should not count twice).
    if rng.rand < 0.2
      again = opened + 40.minutes
      log.("rem_u", openers[rng.rand(openers.size)].id, again)
      status.(false, again)
    end

    swipers.sample(2 + rng.rand(4), random: rng).each do |user|
      2.times { swipe.(user, opened - 30.minutes + rng.rand(240).minutes) }
    end

    # A quick unlock to let someone in, locked again a minute later.
    if rng.rand < 0.3
      buzz = opened - 2.hours
      who = openers[rng.rand(openers.size)]
      log.("rem_u=1", who.id, buzz)
      status.(false, buzz)
      log.("rem_l=1", who.id, buzz + 1.minute)
      status.(true, buzz + 1.minute)
    end

    # How the night ends, roughly as on the real board: most nights the
    # after-hours lock does it, some nights the opener locks up, some nights
    # someone else does.
    closed = opened + (2 + rng.rand(5)).hours + rng.rand(55).minutes
    roll = rng.rand
    if roll < 0.3
      log.("rem_l", opener.id, closed)
    elsif roll < 0.5
      log.("rem_l=1", (openers - [opener]).sample(random: rng).id, closed)
    else
      closed = day + 22.hours
      log.("rem_l", auto_lock, closed)
    end
    status.(true, closed)
  end

  # An unlock the board never confirmed (it was offline): no status row.
  log.("rem_u=1", people["grace"].id, now - 4.days + 2.hours)

  # Things that must never count: a refused rear unlock, a hidden member.
  log.("rem_u=2", people["nikola"].id, now - 3.days)
  log.("rem_u=1", people["vikram"].id, now - 2.days + 18.hours)
  status.(false, now - 2.days + 18.hours)
  log.("rem_l=1", people["vikram"].id, now - 2.days + 20.hours)
  status.(true, now - 2.days + 20.hours)

  # Right now: Hedy unlocked the front door twelve minutes ago.
  swipe.(people["hedy"], now - 15.minutes)
  log.("rem_u=1", people["hedy"].id, now - 12.minutes)
  status.(false, now - 12.minutes)

  puts "Seeded #{DoorLog.count} dev door log rows."
end
