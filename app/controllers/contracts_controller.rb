class ContractsController < ApplicationController
  load_and_authorize_resource :contract
  before_filter :authenticate_user!, :load_users
  layout 'resources'

  def index
    if params[:user_id].present?
      @contracts = Contract.where(user_id: params[:user_id])
    end
    respond_to do |format|
      format.html
      format.json { render :json => @contracts }
    end
  end

  def show
  end

  def new
  end

  def edit
  end

  def create
    @contract.created_by = current_user
    respond_to do |format|
      if @contract.save
        format.html { redirect_to @contract, :notice => 'Contract was successfully created.' }
        format.json { render :json => @contract, :status => :created, :location => @contract }
      else
        format.html { render :action => "new" }
        format.json { render :json => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  def find_for_user
  end

  def update
    respond_to do |format|
      if @contract.update_attributes(contracts_params)
        format.html { redirect_to @contract, :notice => 'Contract was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @contract.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @contract.destroy

    respond_to do |format|
      format.html { redirect_to contracts_url }
      format.json { head :no_content }
    end
  end

  def load_users
    @users = User.accessible_by(current_ability).sort_by(&:name)
  end

  private

  def contracts_params
    params.require(:contract).permit(:user_id, :first_name, :last_name, :cosigner,
      :signed_at, :document, :document_file_name, :document_content_type,
      :document_file_size, :document_updated_at)
  end
end
