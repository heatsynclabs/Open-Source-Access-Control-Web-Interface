class Card < ActiveRecord::Base
  require 'open-uri'

  # The door board addresses cards by slot, and the slot is this row's primary key.
  SLOT_RANGE = (10..200)

  validates_presence_of :user_id, :card_number, :card_permissions
  validates_uniqueness_of :id, :card_number
  # The board reads the tag as exactly 8 hex characters (we left-pad to 8), so a
  # card number must be 1 to 8 hex digits. Only checked when it is actually being
  # set, so editing an older card's other fields is not blocked by legacy data.
  validates_format_of :card_number,
    :with => /\A\h{1,8}\z/,
    :if => :card_number_changed?,
    :message => "must be 1 to 8 hex digits (0-9, A-F), as the reader shows it"
  belongs_to :user

  # When routing through door-api, removing a card from the DB also removes it
  # from the board. Best effort: a door-api failure must not block the delete.
  after_destroy :remove_from_door_api, :if => -> { DoorApiClient.enabled? }

  # Computed per-request in CardsController#index, not a column.
  attr_accessor :accesses_this_week

  # The lowest free door-board slot, or nil if every slot in SLOT_RANGE is taken.
  def self.next_free_slot
    used = where(:id => SLOT_RANGE).pluck(:id)
    (SLOT_RANGE.to_a - used).min
  end

  # Push this one card to the door. Routes through door-api when enabled,
  # otherwise talks to the board directly. Returns true on success, false on a
  # bad reply or an unreachable door (timeouts handled below each path).
  def upload_to_door
    return DoorApiClient.new.put_card(:number => card_number.to_i(16), :doors => door_access_list) if DoorApiClient.enabled?
    source = DoorBoard.get(upload_query)
    source.scan(/cur/).size > 0
  rescue DoorBoard::Unreachable
    false
  end

  # Push every card to the door. Through door-api this is a single reconcile
  # (read once, write deltas); directly it is one request per card.
  def self.upload_all_to_door
    return sync_all_to_door_api if DoorApiClient.enabled?
    Card.all.map do |card|
      slot = card.id.to_s.rjust(3, '0')
      begin
        source = DoorBoard.get(card.upload_query)
        [slot, source.scan(/cur/).size > 0 ? "OK" : "FAIL"]
      rescue DoorBoard::Unreachable
        [slot, "FAIL"]
      end
    end
  end

  # Reconcile the whole card set to the board via door-api. Returns the door-api
  # summary hash ({ "added"=>, "updated"=>, "removed"=>, "failed"=>[] }).
  def self.sync_all_to_door_api
    cards = Card.all.map { |c| { :card => c.card_number.to_i(16), :doors => c.door_access_list } }
    DoorApiClient.new.sync(:cards => cards)
  rescue DoorApiClient::Error => e
    { "error" => e.message }
  end

  # The doors this card may open, as door-api expects: the configured door list
  # when enabled (card_permissions 1), none when disabled (255).
  def door_access_list
    card_permissions == 1 ? Array(APP_CONFIG['door_doors'] || [1, 2]) : []
  end

  # The board's "modify slot" query for this card: zero-padded slot, permission
  # mask and tag, plus the login password. card_number is validated to 1-8 hex,
  # so it cannot contain query-string characters.
  def upload_query
    cardid   = id.to_s.rjust(3, '0')
    cardperm = card_permissions.to_s.rjust(3, '0')
    cardnum  = card_number.rjust(8, '0')
    "m#{cardid}&p#{cardperm}&t#{cardnum}&e=#{APP_CONFIG['door_access_password']}"
  end

  private

  def remove_from_door_api
    DoorApiClient.new.delete_card(card_number.to_i(16))
  rescue => e
    Rails.logger.warn("door-api delete_card failed for card #{id}: #{e.message}")
  end
end
