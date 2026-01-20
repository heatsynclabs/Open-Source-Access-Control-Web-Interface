class ResourcesController < ApplicationController
  load_and_authorize_resource
  before_filter :load_users
  layout 'resources'

  def index
    @featured_resource = @resources.where("picture_file_name IS NOT NULL").sample
  end

  def new
    # don't get too excited... for some reason this gets set to the current_user
    @resource.user_id = nil
  end

  def create
    @resource.modified_by = current_user.id # log who modified this last
    authorize! :create, @resource

    respond_to do |format|
      if @resource.save
        format.html { redirect_to resource_path(@resource), :notice => "Resource was successfully created." }
        format.json { head :no_content }
      else
        format.html { render :action => "new" }
        format.json { render :json => @resource.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @resource.modified_by = current_user.id # log who modified this last
    @resource.assign_attributes(resources_params)
    authorize! :update, @resource

    respond_to do |format|
      if @resource.update_attributes(resources_params)
        format.html { redirect_to resource_path(@resource), :notice => "Resource was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @resource.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @resource.destroy

    respond_to do |format|
      format.html { redirect_to resources_path, :notice => "Resource was deleted." }
      format.json  { head :ok }
    end
  end

  def load_users
    if can? :assign_user, Resource then
      @users = User.accessible_by(current_ability).sort_by(&:name)
    else
      @users = [current_user]
    end
  end

  private

  def resources_params
    params.require(:resources).permit(:supercategory, :user_id, :resource_category_id, :name, :serial, :specs, :status, :donatable,
      :picture, :picture_file_name, :picture_content_type, :picture_file_size, :picture_updated_at,
      :picture2, :picture2_file_name, :picture2_content_type, :picture2_file_size, :picture2_updated_at,
      :picture3, :picture3_file_name, :picture3_content_type, :picture3_file_size, :picture3_updated_at,
      :picture4, :picture4_file_name, :picture4_content_type, :picture4_file_size, :picture4_updated_at,
      :notes, :estimated_value, :disposed_at, :modified_by)
  end
end
