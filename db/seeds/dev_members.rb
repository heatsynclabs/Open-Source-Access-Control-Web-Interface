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

    Card.create!(user_id: user.id, card_number: format("DEV%04d", 1000 + i), card_permissions: 1) if m[:card]

    if m[:waiver]
      first, last = m[:name].split(" ", 2)
      Contract.create!(user_id: user.id, first_name: first, last_name: last,
                       signed_at: (Time.now - (40 + i).days), created_by_id: admin_id)
    end

    Payment.create!(user_id: user.id, date: (Date.today - (i * 3)), amount: m[:level], created_by: admin_id) if m[:pay]
  end

  puts "Seeded #{created} dev members."
end
