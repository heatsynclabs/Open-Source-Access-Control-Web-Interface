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

  # Computed per-request in CardsController#index, not a column.
  attr_accessor :accesses_this_week

  # The lowest free door-board slot, or nil if every slot in SLOT_RANGE is taken.
  def self.next_free_slot
    used = where(:id => SLOT_RANGE).pluck(:id)
    (SLOT_RANGE.to_a - used).min
  end

  # Push this one card to the door board. Returns true only on a decent reply,
  # false on a bad reply or an unreachable board (timeouts handled by DoorBoard).
  def upload_to_door
    source = DoorBoard.get(upload_query)
    source.scan(/cur/).size > 0
  rescue DoorBoard::Unreachable
    false
  end

  # Push every card to the board, one at a time. One unreachable or slow board
  # fails that card (FAIL) and moves on, instead of hanging the whole request.
  def self.upload_all_to_door
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

  # The board's "modify slot" query for this card: zero-padded slot, permission
  # mask and tag, plus the login password. card_number is validated to 1-8 hex,
  # so it cannot contain query-string characters.
  def upload_query
    cardid   = id.to_s.rjust(3, '0')
    cardperm = card_permissions.to_s.rjust(3, '0')
    cardnum  = card_number.rjust(8, '0')
    "m#{cardid}&p#{cardperm}&t#{cardnum}&e=#{APP_CONFIG['door_access_password']}"
  end
end
