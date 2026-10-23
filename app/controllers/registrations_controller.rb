class RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters

  protected

  # Devise 4+ requires strong params; on Rails 3.2 these fields passed through
  # attr_accessible. Permit exactly the membership-application fields a member
  # may set on themselves. The admin/instructor/accountant role flags are
  # deliberately NOT permitted here, so self-signup cannot grant privileges
  # (same boundary the old attr_accessible default list enforced).
  def configure_permitted_parameters
    keys = [:name, :email, :email_visible, :phone, :phone_visible, :postal_code,
            :twitter_url, :facebook_url, :github_url, :website_url,
            :emergency_name, :emergency_phone, :emergency_email,
            :current_skills, :desired_skills, :marketing_source,
            :member_level, :payment_method, :payee]
    devise_parameter_sanitizer.permit(:sign_up, keys: keys)
    devise_parameter_sanitizer.permit(:account_update, keys: keys)
  end

  # After signup
  def after_sign_up_path_for(resource)
    '/users/edit/?flash=welcome_msg'
  end

  # After edit
  def after_update_path_for(resource)
    '/users/edit'
  end

end
