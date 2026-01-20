class PaypalCsvsController < ApplicationController
  load_and_authorize_resource :paypal_csv
  before_filter :authenticate_user!

  def index
  end

  def show
  end

  def new
  end

  def create
    PaypalCsv.batch_import_from_csv(params[:file].path)
    redirect_to paypal_csvs_path, :notice => 'Paypal CSV batch was successfully loaded.'
  end

  def link
    result = @paypal_csv.link_payment
    if result.first
      redirect_to paypal_csvs_url, :notice => 'Payment was successfully linked.'
    else
      redirect_to paypal_csvs_url, :notice => result.last
    end
  end

  private

  def paypal_csv_params
    params.require(:paypal_csv).permit(:data, :_address_status, :_counterparty_status, :_currency, :_fee, :_from_email_address, :_gross, :_item_id, :_item_title, :_name, :_net, :_status, :_time, :_time_zone, :_to_email_address, :_transaction_id, :_type, :date, :string)
  end
end
