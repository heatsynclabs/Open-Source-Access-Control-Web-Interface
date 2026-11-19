class CardsController < ApplicationController
  load_and_authorize_resource except: :authorize
  before_action :authenticate_user!, except: :authorize

  # GET /cards
  # GET /cards.json
  def index
    #@cards = Card.all
    #authorize! :read, @cards
    @cards = @cards.includes(user: :payments).sort_by{|e| e[:id]}

    if can? :read, DoorLog then
      most_active_count = 0
      runner_up_count = 0
      @most_active_card = nil
      @runner_up_card = nil
      @cards.each do |card|
        card_num_R = card.card_number.to_i(16)%32767
        card.accesses_this_week = DoorLog.where("key = ? AND data = ? AND created_at > ?", 'G', card_num_R, DateTime.now - 1.month).order("created_at DESC").group_by { |d| d.created_at.beginning_of_day }.count
      end
      @most_active_cards = @cards.sort{|a,b| b.accesses_this_week <=> a.accesses_this_week}
      @most_active_card = @most_active_cards[0]
      @runner_up_card = @most_active_cards[1]
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => @cards }
    end
  end

  # GET /cards/1
  # GET /cards/1.json
  def show
    if can? :read, DoorLog then
      card_num_R = @card.card_number.to_i(16)%32767
      @door_logs = DoorLog.where('key = ? AND data = ?', "G", card_num_R).order("created_at DESC")
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @card }
    end
  end

  # PUT /cards/1/upload
  def upload
    #@card = Card.find(params[:id])
    @upload_result = @card.upload_to_door

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @upload_result }
    end
  end

  # PUT /cards/upload_all
  def upload_all
    @upload_result = Card.upload_all_to_door

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @upload_result }
    end
  end

  # GET /cards/new
  # GET /cards/new.json
  def new
    # Pre-fill the door-board slot with the lowest free one so an admin does not
    # have to look it up. They can still type a different slot.
    @card.id ||= Card.next_free_slot

    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @card }
    end
  end

  # GET /cards/1/edit
  def edit
    #@card = Card.find(params[:id])
  end

  # POST /cards
  # POST /cards.json
  def create
    # The primary key IS the door-board slot (10..199). Honor the slot the admin
    # typed when it is free; otherwise drop the card into the next free slot so
    # two cards can never land on the same slot. Never fall back to the id
    # sequence, which does not track the hand-assigned slots and would collide.
    @requested_slot = @card.id
    if @requested_slot.blank? || Card.exists?(:id => @requested_slot)
      @card.id = Card.next_free_slot
    end

    respond_to do |format|
      if @card.id.nil?
        @card.errors.add(:base, "Every door slot from 10 to 199 is in use. Disable and delete an old card, then try again.")
        format.html { render :action => "new", :status => :unprocessable_entity }
        format.json { render :json => @card.errors, :status => :unprocessable_entity }
      elsif @card.save
        format.html { redirect_to cards_url, :notice => slot_notice }
        format.json { render :json => @card, :status => :created, :location => @card }
      else
        format.html { render :action => "new" }
        format.json { render :json => @card.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /cards/1
  # PUT /cards/1.json
  def update
    #@card = Card.find(params[:id])

    respond_to do |format|
      if @card.update(card_params)
        format.html { redirect_to cards_url, :notice => 'Card was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @card.errors, :status => :unprocessable_entity }
      end
    end
  end

  def authorize

    # Stop unless signed in already, OR if the supplied user/pass params are good.
    unless current_user || check_auth(params['user'],params['pass'])
      @auth = "bad_user_or_pass"
    else
      # Stop unless the user can access the door system
      unless can? :authorize, Card
        @auth = "bad_user_permissions"
        Rails.logger.warn "----------\r\nWARNING: CARD AUTH ATTEMPT DENIED. USER #{current_user.inspect}\r\n----------"
      else

        begin
          @card = Card.where(["lower(card_number) = ?", params[:id].downcase]).first
          @auth = @card.inspect
          if @card && @card.user
            @auth = @card.user.has_certification?(params[:device])
          else
            @auth = false
          end
        rescue
          @auth = false
        end
      end
    end

    if @card && @card.user
      username = @card.user.name
    else
      username = nil
    end

    render json: [@auth, username]
  end

  # DELETE /cards/1
  # DELETE /cards/1.json
  def destroy
    #@card = Card.find(params[:id])
    respond_to do |format|
      if @card.destroy
        format.html { redirect_to cards_url, :notice => 'Card deleted and removed from the door board.' }
        format.json { head :no_content }
      else
        format.html { redirect_to card_url(@card), :alert => @card.errors.full_messages.to_sentence }
        format.json { render :json => @card.errors, :status => :unprocessable_entity }
      end
    end
  end

  private

  # CanCanCan's load_and_authorize_resource builds and updates the card from the
  # method named for the resource: "card_params". On create it includes :id,
  # because the door-board slot is the primary key and is set from the form. On
  # update it does not: moving a card to another slot would leave the old slot
  # live on the board.
  def card_params
    allowed = [:user_id, :name, :card_number, :card_permissions]
    allowed << :id if action_name == 'create'
    params.require(:card).permit(*allowed)
  end

  # Flash message after a successful create, telling the admin which slot the card
  # actually landed in when the one they asked for was taken or left blank.
  def slot_notice
    if @requested_slot.present? && @requested_slot != @card.id
      "Card created. Slot #{@requested_slot} was already in use, so the card went into the next free slot, #{@card.id}. Upload it to the door board to activate it."
    elsif @requested_slot.blank?
      "Card created in slot #{@card.id}. Upload it to the door board to activate it."
    else
      "Card was successfully created. Upload it to the door board to activate it."
    end
  end
end
