class Api::V1::DoorsController < Api::V1::BaseController
  before_filter :authenticate_user_for_api!
  
  def status
    door_status = DoorLog.show_status
    render json: {
      success: true,
      status: door_status
    }
  end
  
  def control
    unless can? :access_doors_remotely, :door_access
      render json: {
        success: false,
        error: "Sorry, your account isn't able to control doors remotely."
      }, status: :forbidden
      return
    end
    
    unless params['cmd']
      render json: {
        success: false,
        error: "No command specified."
      }, status: :bad_request
      return
    end
    
    # Log the access attempt
    Rails.logger.info "Door access via API: user #{current_user.inspect}, command: #{params['cmd']}"
    
    # Create door log entry with remote API prefix
    DoorLog.create!({
      :key => "api_rem_"+DoorLog.parse_command(params['cmd'])[:url_param], 
      :data => current_user.id
    })
    
    # Execute the command (with same rear door restriction as original)
    if params['cmd'] == "unlock-rear"
      result = "Attempted to unlock the back door. This is no longer allowed."
      Rails.logger.warn "----------\r\nWARNING: ATTEMPTED TO UNLOCK REAR DOOR VIA API. USER #{current_user.inspect}\r\n----------"
    else
      result = DoorLog.execute_command(params['cmd'])
    end
    
    render json: {
      success: true,
      result: result,
      command: params['cmd']
    }
  end
  
  private
  
  def authenticate_user_for_api!
    unless current_user
      render json: {
        success: false,
        error: "Authentication required. Please login first via /api/v1/login"
      }, status: :unauthorized
    end
  end
end