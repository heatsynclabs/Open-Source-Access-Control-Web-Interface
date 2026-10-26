class PaypalCsvsController < ApplicationController
  load_and_authorize_resource :paypal_csv, :except => [:assign]
  before_action :authenticate_user!

  def index
    @paypal_csvs = @paypal_csvs.includes(:payment)
    if params[:needs_review]
      # Unlinked rows that look like money coming in to the lab, newest first.
      @needs_review = true
      @paypal_csvs = @paypal_csvs.where(:payment_id => nil).order("paypal_csvs.id DESC").limit(1000)
                                 .select(&:incoming_payment?)
    else
      @paypal_csvs = @paypal_csvs.order("paypal_csvs.id DESC")
      @paypal_csvs = @paypal_csvs.limit(1000) unless params[:all]
    end
  end

  def show
  end

  def new
  end

  def create
    @summary = PaypalCsv.batch_import_from_csv(params[:file].path)
    notice = "Imported #{@summary[:imported]} rows (#{@summary[:skipped_duplicates]} duplicates skipped). " \
             "Linked #{@summary[:linked]} payments; #{@summary[:queued]} need review."
    redirect_to paypal_csvs_path(:needs_review => 1), :notice => notice
  end

  # Link one row. With a user_id, link to that chosen member (reconciliation);
  # with "remember", store the payer email on that member so it auto-links next
  # time. Without a user_id, try to auto-match by payer email.
  def link
    if params[:user_id].present?
      user = User.find(params[:user_id])
      result = @paypal_csv.link_to_user!(user)
      if result.first && params[:remember].present? && user.payee.blank?
        user.update_column(:payee, @paypal_csv.payer_email)
      end
    else
      result = @paypal_csv.link_payment
    end
    redirect_to paypal_csvs_path(:needs_review => 1),
                :notice => (result.first ? 'Payment linked.' : result.last)
  end

  # Map a payer email to a member and relink. Sets the member's payee so every
  # future payment from that email auto-links. Assign the same payer to a second
  # member to handle one email that pays for several people.
  def assign
    authorize! :manage, PaypalCsv
    payer = params[:payer_email].to_s.strip.downcase
    user  = User.where("lower(email) = ?", params[:member_email].to_s.strip.downcase).first
    if user.nil?
      redirect_to paypal_csvs_path(:needs_review => 1), :alert => "No member with email '#{params[:member_email]}'."
      return
    end
    if user.payee.present? && user.payee.strip.downcase != payer
      redirect_to paypal_csvs_path(:needs_review => 1),
                  :alert => "#{user.email} already has payee '#{user.payee}'. Clear it on their profile first."
      return
    end
    user.update_column(:payee, payer) if user.payee.blank?
    res = PaypalCsv.reconcile_unlinked!
    redirect_to paypal_csvs_path(:needs_review => 1),
                :notice => "Mapped #{payer} to #{user.email}. Linked #{res[:linked]} payment(s)."
  end

  private

  def paypal_csv_params
    params.require(:paypal_csv).permit(:data, :_address_status, :_counterparty_status, :_currency, :_fee, :_from_email_address, :_gross, :_item_id, :_item_title, :_name, :_net, :_status, :_time, :_time_zone, :_to_email_address, :_transaction_id, :_type, :date, :string)
  end
end
