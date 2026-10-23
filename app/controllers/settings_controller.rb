class SettingsController < ApplicationController
  authorize_resource

  # Settings are declared as fields on the Setting model (rails-settings-cached).
  # Each field carries its own default, so there is no separate defaults hash.
  def index
    @settings = Setting.defined_fields.to_h { |field| [field.key, Setting.send(field.key).to_s] }
  end

  def edit
    key = params[:id]
    if Setting.respond_to?(key)
      @setting = { :var => key, :value => Setting.send(key).to_s }
    else
      redirect_to settings_path
    end
  end

  def update
    key = params[:id]
    Setting.send("#{key}=", params[:value]) if Setting.respond_to?("#{key}=")

    redirect_to settings_path
  end

  private

  def settings_params
    params.require(:setting).permit(:var)
  end
end
