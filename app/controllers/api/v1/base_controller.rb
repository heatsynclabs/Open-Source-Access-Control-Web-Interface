class Api::V1::BaseController < ApplicationController
  protect_from_forgery :except => [:login, :status, :control]
  skip_before_action :authenticate_user!
  
  private
  
  def render_unauthorized
    render json: { success: false, error: "Unauthorized" }, status: :unauthorized
  end
end