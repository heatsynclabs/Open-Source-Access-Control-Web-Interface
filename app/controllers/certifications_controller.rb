class CertificationsController < ApplicationController
  load_and_authorize_resource :certification
  #load_and_authorize_resource :user, :through => :certification
  before_action :authenticate_user!

  # GET /certifications
  # GET /certifications.json
  def index
    @certifications = @certifications.sort_by(&:name)

    respond_to do |format|
      format.html { load_board }
      format.json { render :json => @certifications }
    end
  end

  # GET /certifications/1
  # GET /certifications/1.json
  def show
    respond_to do |format|
      format.html { load_board(@certification) }
      format.json { render :json => @certification }
    end
  end

  # GET /certifications/new
  # GET /certifications/new.json
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @certification }
    end
  end

  # GET /certifications/1/edit
  def edit
  end

  # POST /certifications
  # POST /certifications.json
  def create
    respond_to do |format|
      if @certification.save
        format.html { redirect_to Certification, :notice => 'Certification was successfully created.' }
        format.json { render :json => @certification, :status => :created, :location => @certification }
      else
        format.html { render :action => "new" }
        format.json { render :json => @certification.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /certifications/1
  # PUT /certifications/1.json
  def update
    respond_to do |format|
      if @certification.update(certification_params)
        format.html { redirect_to Certification, :notice => 'Certification was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @certification.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /certifications/1
  # DELETE /certifications/1.json
  def destroy
    @certification.destroy

    respond_to do |format|
      format.html { redirect_to certifications_url }
      format.json { head :no_content }
    end
  end

  private

  def certification_params
    params.require(:certification).permit(:description, :name, :slug)
  end

  # The certifications page: every tool with its holder count (busiest
  # first), the chosen tool's holders, the latest sign-offs, and the members
  # an instructor can sign off. Only holders the viewer may see are counted.
  def load_board(selected = nil)
    sign_offs = UserCertification.accessible_by(current_ability).includes(:user).to_a
      .select { |sign_off| sign_off.user && can?(:read, sign_off.user) }
    @holders = sign_offs.group_by(&:certification_id)
    @tools = Certification.accessible_by(current_ability).to_a
      .sort_by { |tool| [-@holders.fetch(tool.id, []).size, tool.name.to_s.downcase] }
    @tool = selected || @tools.first
    @newest_first = params[:order] == "new"
    @recent_sign_offs = sign_offs.sort_by(&:created_at).last(30).reverse
    @signed_off_by = User.where(id: sign_offs.map(&:created_by).compact.uniq).pluck(:id, :name).to_h
    @members = User.where(:hidden => [false, nil]).accessible_by(current_ability).order(:name).pluck(:name, :id) if can?(:create, UserCertification)
  end
end
