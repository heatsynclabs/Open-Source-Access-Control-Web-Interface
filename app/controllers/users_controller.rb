class UsersController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!
  layout 'resources'

  def sort_by_cert(certs,id)
    result = 0
    certs.each do |c|
      if c.id == id
        result = 1
      end
    end
    return result
  end

  # GET /users
  # GET /users.json
  def index
    unless params[:full] # by default, show summary

      # sort in SQL instead of loading every user and sorting in Ruby;
      # eager-load payments because the badges partial's member_status_symbol
      # reads them for every user rendered
      @users = @users.active.includes(:payments).order('users.member_level DESC, LOWER(users.name) ASC')
#@users.paying + @users.volunteer
#.joins(:payments).where("payments.date > ? OR ", (DateTime.now - 60.days)).uniq

      respond_to do |format|
        format.html { render 'summary', layout: 'resources' }
        format.json { render :json => @users }
      end

    else # show full

      # eager-load what the view touches per row (member_status_symbol reads
      # payments; the table shows cards and certifications) so the page runs
      # a handful of queries instead of several per user
      @users = @users.includes(:payments, :cards, :user_certifications, :contracts)

      case params[:sort]
      when "name"
        @users = @users.order('LOWER(users.name) ASC')
      when "cert"
        # sort on the eager-loaded association in Ruby: naming cards or
        # user_certifications in a SQL ORDER BY flips Rails 3.2 into
        # join-based eager loading, whose row fanout is far slower
        cert_id = params[:cert].to_i
        @users = @users.sort_by{ |u| [-(u.user_certifications.any?{|uc| uc.certification_id == cert_id} ? 1 : 0), u.name.downcase] }
      when "orientation"
        @users = @users.order('users.orientation DESC NULLS LAST, LOWER(users.name) ASC')
      when "waiver"
        @users = @users.order('(SELECT MIN(c.signed_at) FROM contracts c WHERE c.user_id = users.id) DESC NULLS LAST, LOWER(users.name) ASC')
      when "member"
        # member_status is computed in Ruby, but payments are eager-loaded so
        # this no longer issues a query per user
        @users = @users.sort_by{ |u| [-u.member_status.to_i,u.name.downcase] }
      when "card"
        @users = @users.sort_by{ |u| [-u.cards.length, u.name.downcase] }
      when "instructor"
        @users = @users.order('COALESCE(users.instructor, false) DESC, users.name ASC')
      when "admin"
        @users = @users.order('COALESCE(users.admin, false) DESC, users.name ASC')
      else
        @users = @users.order('LOWER(users.name) ASC')
      end


      respond_to do |format|
        format.html # index.html.erb
        format.json { render :json => @users }
      end
    end
  end

  # Members who currently hold an active door card (card_permissions = 1,
  # the same definition as User#card_access_enabled). Names + avatars only.
  def active_cardholders
    # Compute the gravatar hash in SQL (md5(lower(trim(email))), same as
    # Gravtastic) so the raw email never leaves the database - the view only
    # gets id, name, and the hash. Exclude hidden members since this list is
    # visible to every logged-in user.
    @cardholders = User.select(
      "users.name, md5(lower(btrim(users.email))) AS gravatar_hash"
    ).where(
      "(users.hidden IS NULL OR users.hidden = ?) AND users.id IN " +
      "(SELECT user_id FROM cards WHERE card_permissions = ? AND user_id IS NOT NULL)", false, 1
    ).order("LOWER(users.name)")
  end

  # 'Active' users who haven't paid recently
  def inactive
    # eager-load payments (payment_status/delinquency) plus the cards and
    # certifications shown in the view, so this is a few queries total
    # instead of several per user
    @users = @users.includes(:payments, :cards, :certifications).all.select{|u| u if u.payment_status == false }.sort_by{ |u| -u.delinquency }
  end

  # Recent user activity
  def activity
    @zombie_members = User.where('sign_in_count = 0').where('member_level > 1')
    @user_logins = User.where(:current_sign_in_at => 2.months.ago..Time.now).where('sign_in_count > 1')
    @new_users = User.where(:created_at => 3.months.ago..Date.today)
    @cardless_users = User.includes('cards').where(['users.member_level >= ?','50']).where('cards.id IS NULL')
  end

  # New members (for emailing out)
  def new_member_report
    # hidden is NULL (not false) for users nobody has explicitly hidden, and
    # the range must end at Time.now or people who signed up today are excluded
    @new_users = User.where(:created_at => 3.months.ago..Time.now).where(:hidden => [false, nil]).where(['member_level >= ?','1'])
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @payments = Payment.where(:user_id => @user.id).order('date desc').limit(10)
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @user }
    end
  end

  def compose_email
    @user = User.find(params[:user_id])
  end

  def send_email
    @user = User.find(params[:user_id])
    @subject = params[:subject]
    @body = params[:body]
    if @user.send_email(current_user,@subject,@body)
      redirect_to user_path(@user), :notice => "Email sent successfully."
    else
      flash[:alert] = "Error sending email."
      render :compose_email
    end
  end

  # GET /user_summary/1
  def user_summary
    respond_to do |format|
      format.html { render :partial => "user_summary" } # show.html.erb
      format.json { render :json => @user }
    end
  end

  # GET /users/new
  # GET /users/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @user }
    end
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    # load_and_authorize_resource already built @user from user_params, which
    # only permits the role flags (admin/instructor/accountant) when the
    # current user is an admin, so no extra role-aware assignment is needed.

    # update oriented_by only if orientation has been set
    @user.oriented_by_id = current_user.id unless @user.orientation.blank?

    respond_to do |format|
      if @user.save
        audit_event("user_create", @user, "created user #{@user.name} (#{@user.email})")
        format.html { redirect_to @user, :notice => 'User was successfully created.' }
        format.json { render :json => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.json
  def update
    # update oriented_by only if it's blank but the (new) orientation isn't blank
    # gotta test the params because they don't get applied til below.
    @user.oriented_by_id = current_user.id if @user.oriented_by.blank? && (!params[:user]["orientation(1i)"].blank?)

    respond_to do |format|
      if @user.update(user_params)
        # log edits of *other* people's profiles (self-service edits go through
        # Devise and are intentionally not audited)
        if current_user.id != @user.id
          changes = AuditEvent.diff(@user)
          audit_event("user_update", @user, changes.presence || "(no field changes)")
        end
        format.html { redirect_to @user, :notice => 'User was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # GET /users/merge
  def merge_view
    @users = @users.sort_by(&:name)

    respond_to do |format|
      format.html # merge_view.html.erb
    end
  end

  # POST /users/merge
  def merge_action
    @user_to_keep = User.find(params[:user][:to_keep])
    Rails.logger.info "USER TO KEEP:"
    Rails.logger.info @user_to_keep.inspect
    @user_to_merge = User.find(params[:user][:to_merge])
    Rails.logger.info "USER TO MERGE:"
    Rails.logger.info @user_to_merge.inspect

    @user_to_keep.absorb_user(@user_to_merge)

    Rails.logger.info "RESULT:"
    Rails.logger.info @user_to_keep.inspect
    Rails.logger.info @user_to_keep.cards.inspect
    Rails.logger.info @user_to_keep.user_certifications.inspect
    Rails.logger.info @user_to_keep.payments.inspect

    respond_to do |format|
      format.html { redirect_to @user_to_keep, :notice => 'Users successfully merged.' }
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, :notice => 'User successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def user_params
    permitted = [:email, :password, :password_confirmation, :remember_me, :name, :emergency_name, :emergency_phone, :current_skills, :desired_skills, :waiver, :emergency_email, :phone, :payment_method, :orientation, :member_level, :certifications, :hidden, :marketing_source, :payee, :exit_reason, :twitter_url, :facebook_url, :github_url, :website_url, :email_visible, :phone_visible, :postal_code]
    # role flags are assignable only by admins (parity with the old
    # attr_accessible :as => :admin behavior)
    permitted += [:admin, :instructor, :accountant] if current_user && current_user.admin?
    params.require(:user).permit(*permitted)
  end
end
