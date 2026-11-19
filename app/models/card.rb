class Card < ActiveRecord::Base
  require 'open-uri'

  # The door board addresses cards by slot, and the slot is this row's primary key.
  # The firmware lists slots 0..199; writing slot 200 runs past the end of its
  # EEPROM and overwrites the alarm settings, so 199 is the last usable slot.
  SLOT_RANGE = (10..199)
  BOARD_SLOTS = (0..199)

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

  # Deleting a card first clears its slot on the door board, so a deleted card
  # can no longer open the door. If the board does not confirm, the card is kept
  # and the admin sees why (errors[:base]).
  before_destroy :remove_from_board

  # Computed per-request in CardsController#index, not a column.
  attr_accessor :accesses_this_week
  # Who is changing the card (e.g. "user 12"), for door-api's audit log. Set by
  # CardsController; not stored.
  attr_accessor :door_actor

  # A new card's id is its slot on the door board, which the board uses only
  # from 0 to 199 (members keeps 0..9 free). The form limits it too; this is the
  # server-side check.
  validate :slot_in_range, :on => :create

  # The lowest free door-board slot, or nil if every slot in SLOT_RANGE is taken.
  def self.next_free_slot
    used = where(:id => SLOT_RANGE).pluck(:id)
    (SLOT_RANGE.to_a - used).min
  end

  # Push this one card to the door: slot = card id, permission mask, tag. Through
  # door-api when enabled (it sends the board the same ?m query and checks the
  # board's read-back), otherwise directly. True on success, false otherwise.
  def upload_to_door
    if DoorApiClient.enabled?
      DoorApiClient.new(:actor => door_actor).put_slot(id, card_number, card_permissions)
      return true
    end
    source = DoorBoard.get(upload_query)
    source.scan(/cur/).size > 0
  rescue DoorBoard::Unreachable, DoorApiClient::Error
    false
  end

  # Push every card to the door, one request per card, on either path.
  # Returns [[slot, "OK" | "FAIL"], ...].
  def self.upload_all_to_door(actor: nil)
    Card.all.map do |card|
      card.door_actor = actor
      [card.id.to_s.rjust(3, '0'), card.upload_to_door ? "OK" : "FAIL"]
    end
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

  def slot_in_range
    return if id.nil? || SLOT_RANGE.cover?(id)
    errors.add(:id, "must be a door-board slot from #{SLOT_RANGE.first} to #{SLOT_RANGE.last}")
  end

  def remove_from_board
    unless BOARD_SLOTS.cover?(id)
      # Not a slot the board has (an old id). Writing it would hit another slot
      # or the alarm settings, so only the row is removed.
      Rails.logger.warn("Card #{id} is outside the board's slots; deleting the row only")
      return
    end
    confirmed =
      if DoorApiClient.enabled?
        DoorApiClient.new(:actor => door_actor).clear_slot(id)
        true
      else
        DoorBoard.get("r#{id.to_s.rjust(3, '0')}&e=#{APP_CONFIG['door_access_password']}").include?('cur:')
      end
    unless confirmed
      errors.add(:base, "The door board did not confirm removing slot #{id}, so the card was not deleted. Try again.")
      throw :abort
    end
  rescue DoorBoard::Unreachable, DoorApiClient::Error => e
    errors.add(:base, "Could not reach the door board (#{e.message}), so the card was not deleted. Try again.")
    throw :abort
  end
end
