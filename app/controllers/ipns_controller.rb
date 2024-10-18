class IpnsController < ApplicationController
  load_and_authorize_resource :ipn, :except => [:new, :create]
  before_filter :authenticate_user!, :except => [:new, :create]

  protect_from_forgery :except => [:create]

  def index
    @ipns = Ipn.all
  end

  def show
  end

  def new
  end

  def create
    @ipn = Ipn.new_from_dynamic_params(ipn_params)
    @ipn.data = ipn_params.to_json
    @ipn.save
    render :nothing => true
    #unless @ipn.validate!
    #  Rails.logger.error "Unable to validate IPN: #{@ipn.inspect}"
    #end
  end

  def import
    @ipn = Ipn.new_from_dynamic_params(ipn_params)
    @ipn.data = ipn_params.to_json
    @ipn.save
    redirect_to ipn_path(@ipn)
    #unless @ipn.validate!
    #  Rails.logger.error "Unable to validate IPN: #{@ipn.inspect}"
    #end
  end

  def validate
    if @ipn.validate!
      redirect_to ipns_url, :notice => 'Valid!'
    else
      redirect_to ipns_url, :notice => 'INVALID'
    end
  end

  def link
    result = @ipn.link_payment
    if result.first
      redirect_to ipns_url, :notice => 'Payment was successfully linked.'
    else
      redirect_to ipns_url, :notice => result.last
    end
  end

  private

  def ipn_params
    params.require(:ipn).permit(:data)
  end
end
