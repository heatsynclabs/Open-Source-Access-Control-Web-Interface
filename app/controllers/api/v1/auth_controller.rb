class Api::V1::AuthController < Api::V1::BaseController
  
  def login_method_error
    render json: { 
      success: false, 
      error: "Method not allowed. Use POST to /api/v1/login with email and password in request body.",
      expected_method: "POST",
      expected_body: {
        email: "user@example.com",
        password: "password"
      }
    }, status: :method_not_allowed
  end
  
  def login
    if check_auth(params['email'], params['password'])
      user = current_user
      render json: {
        success: true,
        user: serialize_user(user),
        capabilities: user_capabilities(user)
      }
    else
      render json: { 
        success: false, 
        error: "Invalid email or password" 
      }, status: :unauthorized
    end
  end
  
  def logout
    sign_out current_user if current_user
    render json: { success: true, message: "Logged out successfully" }
  end
  
  def status
    if current_user
      render json: { 
        logged_in: true, 
        user: serialize_user(current_user),
        capabilities: user_capabilities(current_user)
      }
    else
      render json: { logged_in: false }
    end
  end
  
  private
  
  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      member_level: user.member_level,
      member_level_string: user.member_level_string,
      orientation_complete: !user.orientation.blank?,
      payment_status: user.payment_status,
      last_sign_in: user.last_sign_in_at
    }
  end
  
  def user_capabilities(user)
    {
      door_access: user.card_access_enabled,
      admin: user.admin?,
      instructor: user.instructor?,
      accountant: user.accountant?,
      can_access_remotely: (user.card_access_enabled && can?(:access_doors_remotely, :door_access))
    }
  end
end