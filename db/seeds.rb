require_relative "seeds/admin.rb"
require_relative "seeds/defaults.rb"
require_relative "seeds/dev_members.rb"

initialize_local_admin!
set_defaults!
seed_dev_members!

