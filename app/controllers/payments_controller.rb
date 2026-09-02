class PaymentsController < ApplicationController
  load_and_authorize_resource :payment
  #load_and_authorize_resource :user, :through => :payment
  before_filter :authenticate_user!

  # Load users and certs based on current ability (only the form actions
  # use @users - index was paying for this load on every request)
  before_filter :only => [:new, :edit, :create, :update, :show] do
    @users = User.where(:hidden => false).where("member_level > 10").accessible_by(current_ability).sort_by(&:name_with_payee_and_member_level)
  end

  before_filter :only => [:create, :update] do
    @payment.created_by = current_user.id
  end

  # GET /payments
  # GET /payments.json
  def index
    # the table and the chart aggregation both read payment.user per row -
    # eager-load users so that's one query, not one per payment
    @payments = @payments.includes(:user).order("date DESC")
    @graph = { :members => chart("members"),
      :total => chart("total"),
      :basic => chart("basic"),
      :associate => chart("associate")}

    # charts aggregate every payment, but render only recent rows by default
    @payments_shown = params[:all] ? @payments : @payments.first(1000)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => @payments }
    end
  end

  # Private method for index charts
  def chart name
    chart_name = name || "total"
    if chart_name == "total"
      chart_type = [25, 50, 100]
    elsif chart_name == "members"
      chart_type = [25, 50, 100]
    elsif chart_name == "basic"
      chart_type = [50]
    elsif chart_name == "associate"
      chart_type = [25]
    else
      chart_type = [] 
    end

    # memoized: four charts share one sort+group pass over all payments
    payment_months = (@payment_months ||= @payments.sort_by(&:date).group_by{ |p| p.date.beginning_of_month })
    @payments_by_month = []
    payment_months.each do |month|
      # Calculate sum of amounts for each month and store at end of month array
      @payments_by_month << [month.first.to_time.to_i*1000, month.last.sum{|p| 
        amount = amount_or_level(p)
        if chart_type.include?(amount)
          if chart_name == "members"
            1 # Output 1 to count members
          else
            amount # Output dollars to count amount
          end
        else
          0
        end
      }]
    end

    return @payments_by_month
  end

  def amount_or_level p
    if p.amount
      return p.amount.to_i
    else
      if p.user
        return p.user.member_level.to_i
      else
        return 0
      end
    end 
  end

  # GET /payments/1
  # GET /payments/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @payment }
    end
  end

  # GET /payments/new
  # GET /payments/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @payment }
    end
  end

  # GET /payments/1/edit
  def edit
  end

  # POST /payments
  # POST /payments.json
  def create
    Rails.logger.warn "payment:"
    Rails.logger.warn @payment.inspect
    respond_to do |format|
      if @payment.save
        audit_event("payment_created", @payment,
                    "recorded payment ##{@payment.id}: $#{@payment.amount} dated #{@payment.date}",
                    @payment.user)
        format.html { redirect_to payments_url, :notice => 'Payment was successfully created.' }
        format.json { render :json => @payment, :status => :created, :location => @payment }
      else
        format.html { render :action => "new" }
        format.json { render :json => @payment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /payments/1
  # PUT /payments/1.json
  def update
    respond_to do |format|
      if @payment.update_attributes(params[:payment])
        changes = AuditEvent.diff(@payment)
        audit_event("payment_updated", @payment,
                    "updated payment ##{@payment.id}\n#{changes}", @payment.user)
        format.html { redirect_to payments_url, :notice => 'Payment was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @payment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /payments/1
  # DELETE /payments/1.json
  def destroy
    pay_user = @payment.user
    pay_desc = "deleted payment ##{@payment.id}: $#{@payment.amount} dated #{@payment.date}"
    deleted = @payment
    @payment.destroy
    audit_event("payment_deleted", deleted, pay_desc, pay_user)

    respond_to do |format|
      format.html { redirect_to payments_url }
      format.json { head :no_content }
    end
  end
end
