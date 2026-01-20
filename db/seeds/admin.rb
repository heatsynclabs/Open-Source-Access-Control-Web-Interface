def initialize_local_admin!
  if Rails.env.development?
    admin = User.find(email: "admin@example.com")
    return if admin

    User.create({
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password",
      name: "Admin",
      admin: true
    })
  end
end
