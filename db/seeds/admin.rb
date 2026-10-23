def initialize_local_admin!
  if Rails.env.development?
    admin = User.find_by(email: "admin@example.com")
    return if admin

    # include the presence-validated fields so the dev admin actually saves
    User.create!({
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password",
      name: "Admin",
      postal_code: "85201",
      current_skills: "seeded",
      desired_skills: "seeded",
      marketing_source: "seed",
      admin: true
    })
  end
end
