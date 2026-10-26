require 'csv'
require 'bigdecimal'

# Imports a PayPal "Activity" CSV and reconciles each incoming membership
# payment to a member. Reconciliation is Option A: a member who is paid for by
# someone else carries that payer's email in their `payee` field, so one payer
# email can fund several member accounts. The importer links what it can and
# leaves the rest unlinked for a human to assign on the reconciliation screen;
# assigning a row there can set `payee`, so it auto-links next month.
#
# Nothing here changes member_level or card access. It only creates Payment rows.
class PaypalCsv < ActiveRecord::Base
  belongs_to :payment

  # Who the lab receives dues at, and the dues tiers. Overridable by env so the
  # code does not need editing when these change. Tiers are for reporting only;
  # linking records the actual amount paid (grandfathered amounts still count).
  RECEIVER_EMAILS = (ENV['PAYPAL_RECEIVER_EMAILS'] || 'hslfinances@gmail.com')
                      .downcase.split(/[\s,]+/).reject(&:empty?)
  CURRENT_TIERS   = (ENV['MEMBERSHIP_TIERS'] || '25,50,100')
                      .split(',').map { |s| s.strip.to_i }.reject(&:zero?)

  # PayPal transaction types that represent money coming in for membership.
  # Matched case-insensitively and trimmed, so a PayPal rename (for example
  # "Subscription Payment Processed" -> "Subscription Payment") does not break
  # the import again.
  DUES_TYPES = [
    'subscription payment', 'subscription payment processed',
    'recurring payment received', 'recurring payment',
    'website payment', 'general payment', 'mobile payment',
    'express checkout payment', 'payment received'
  ].freeze

  # ---------------------------------------------------------------- field access
  # Tolerant parsing of the raw CSV string fields.

  def gross_amount
    raw = self._gross.to_s.gsub(/[^0-9.\-]/, '') # strip "$" and "," -> "$1,000.00"
    return nil if raw.empty?
    BigDecimal(raw)
  rescue ArgumentError
    nil
  end

  def date_value
    Date.strptime(self.date.to_s, '%m/%d/%Y')
  rescue ArgumentError
    nil
  end

  # Sortable date for views; never raises.
  def date_parsed
    date_value || Date.new(0)
  end

  def payer_email;    self._from_email_address.to_s.strip.downcase; end
  def receiver_email; self._to_email_address.to_s.strip.downcase;   end

  def completed?;  self._status.to_s.strip.casecmp('Completed').zero?; end
  def dues_type?;  DUES_TYPES.include?(self._type.to_s.strip.downcase); end

  # A row that should become a membership payment: completed, received by the
  # lab, a membership-ish type, and a positive amount.
  def incoming_payment?
    completed? && RECEIVER_EMAILS.include?(receiver_email) &&
      dues_type? && gross_amount && gross_amount > 0
  end

  # Why a row is not linked, for the reconciliation screen.
  def unlinked_reason
    return nil if payment_id.present?
    return 'not a completed payment'      unless completed?
    return 'not received by the lab'      unless RECEIVER_EMAILS.include?(receiver_email)
    return "ignored type '#{self._type}'" unless dues_type?
    return 'non-positive amount'          unless gross_amount && gross_amount > 0
    return 'unreadable date'              unless date_value
    cands = PaypalCsv.members_for(payer_email)
    return "payer '#{payer_email}' maps to no member" if cands.empty?
    'more payments this month than mapped members'
  end

  # Members keyed to a payer email, by their own email or their payee field.
  def self.members_for(email)
    e = email.to_s.strip.downcase
    return [] if e.empty?
    User.where('lower(email) = ? OR lower(payee) = ?', e, e).to_a
  end

  # ------------------------------------------------------------------- importing
  # Loads the CSV, skips rows already imported (by Transaction ID), then
  # reconciles. Returns a summary hash.
  def self.batch_import_from_csv(filename)
    created = 0
    skipped = 0
    CSV.foreach(filename, headers: true, encoding: 'bom|utf-8') do |row|
      txn = cell(row, 'Transaction ID').to_s.strip
      if txn.present? && exists?(_transaction_id: txn)
        skipped += 1
        next
      end
      pc = new
      header_map(row.headers).each do |col, header|
        pc[col] = row[header]
      end
      pc.data = row.to_h.to_json
      pc.save
      created += 1
    end
    result = reconcile_unlinked!
    result.merge(imported: created, skipped_duplicates: skipped)
  end

  # Links every unlinked incoming row it can. Groups a payer's payments by month
  # and gives each to a distinct member who has no payment that month yet; extra
  # payments (payer funds more members than are mapped) stay unlinked.
  def self.reconcile_unlinked!
    pending = where(payment_id: nil).select(&:incoming_payment?)
    groups = pending.group_by { |r| [r.payer_email, r.date_value && r.date_value.strftime('%Y-%m')] }
    linked = 0
    queued = 0
    groups.each do |(email, month), rows|
      next (queued += rows.size) if month.nil?
      cands = members_for(email)
      next (queued += rows.size) if cands.empty?
      # One candidate: every payment from this email is that member's, so link
      # them all (the DB allows at most one per member per DATE, which covers an
      # in-month upgrade like a 25 then a 50). Several candidates: the email pays
      # for several members, so spread one per member per month.
      single = (cands.size == 1)
      used = []
      rows.each do |r|
        d = r.date_value
        user = cands.find do |u|
          next false if !single && used.include?(u.id)
          !Payment.where(user_id: u.id).where(date: d).exists?
        end
        if user && r.link_to_user!(user).first
          used << user.id unless single
          linked += 1
        else
          queued += 1
        end
      end
    end
    { linked: linked, queued: queued }
  end

  # ------------------------------------------------------------------- linking
  # Create the Payment for an explicitly chosen member (used by the
  # reconciliation screen, and by reconcile_unlinked!).
  def link_to_user!(user)
    return [false, 'already linked'] if payment_id.present?
    d = date_value
    amt = gross_amount
    return [false, 'unreadable date']  unless d
    return [false, 'bad amount']       unless amt && amt > 0
    pay = Payment.new(:user_id => user.id, :date => d, :amount => amt)
    if pay.save
      update_column(:payment_id, pay.id)
      [true]
    else
      [false, "payment error: #{pay.errors.full_messages.first}"]
    end
  end

  # Single-row auto-link: find the member by payer email, then link. Used by the
  # existing "link" button for one row.
  def link_payment
    create_payment
  end

  private

  def create_payment
    return [false, 'not an incoming completed membership payment'] unless incoming_payment?
    cands = PaypalCsv.members_for(payer_email)
    return [false, "no member matches payer '#{payer_email}'"] if cands.empty?
    link_to_user!(cands.first)
  end

  # ------------------------------------------------------------------- helpers
  # Map model columns to the matching CSV header, tolerant of spacing/case and
  # the leading underscore convention (_from_email_address <- "From Email Address").
  def self.header_map(headers)
    norm = lambda { |s| s.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '') }
    by_norm = {}
    headers.each { |h| by_norm[norm.call(h)] = h if h }
    map = {}
    (column_names - %w[id payment_id data created_at updated_at]).each do |col|
      header = by_norm[norm.call(col.sub(/\A_/, ''))]
      map[col] = header if header
    end
    map
  end

  def self.cell(row, header)
    row[header]
  end
end
