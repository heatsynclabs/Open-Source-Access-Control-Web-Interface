class AuditEvent < ActiveRecord::Base
  belongs_to :editor, :class_name => "User"
  belongs_to :affected_user, :class_name => "User"

  # never record secrets, and skip bookkeeping columns that change on every save
  IGNORED_ATTRS = %w[
    updated_at created_at encrypted_password password password_confirmation
    reset_password_token reset_password_sent_at remember_created_at
    sign_in_count current_sign_in_at last_sign_in_at
    current_sign_in_ip last_sign_in_ip
  ].freeze

  scope :recent, -> { order("created_at DESC") }

  # Turn ActiveModel previous_changes into a readable "field: old => new" block.
  def self.diff(record, extra_ignored = [])
    ignored = IGNORED_ATTRS + extra_ignored.map(&:to_s)
    record.previous_changes.reject { |k, _| ignored.include?(k) }.map do |k, (old_v, new_v)|
      "#{k}: #{old_v.inspect} => #{new_v.inspect}"
    end.join("\n")
  end
end
