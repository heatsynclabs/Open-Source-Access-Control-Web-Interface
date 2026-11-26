# The LED marquee in the front window (see Marquee). Door-card holders can put
# a message up and use the presets; admins also set what it shows between
# messages and can restart it.
#
# The page itself never waits on the sign: its live status and the rotation
# form load into Turbo Frames, so a sign that is unplugged costs those frames
# a couple of seconds and the page none. Every action is recorded in the
# audit log, and every failure to reach the sign is shown, never raised.
class MarqueeController < ApplicationController
  before_action :authenticate_user!
  before_action :require_use
  before_action :require_manage, only: [:rotation, :update_rotation, :poll, :restart]

  # A sign in a shop window is easy to flood; keep it to a message every few
  # seconds per member.
  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: :message,
             with: -> { redirect_to marquee_path, alert: "That is a lot of messages. Give the sign a minute." }

  def show
    @can_manage = can?(:manage, :marquee)
    @recent = AuditEvent.where(event_type: "marquee.message").recent.limit(8) if @can_manage
  end

  # Turbo Frame: what the sign is doing right now.
  def panel
    @state = frame_call { client.state }
    @error ||= "the sign sent an unexpected reply" unless @state.is_a?(Hash)
    render layout: false
  end

  # Turbo Frame (admins): the rotation form, filled from the sign.
  def rotation
    doc = frame_call { client.rotation }
    @rotation = Marquee::Rotation.from_panel(doc) unless @error
    render layout: false
  end

  def message
    cmd = Marquee.message_command(text: params[:text], color: params[:color], repeat: params[:repeat])
    return redirect_to(marquee_path, alert: "Type something to show first.") unless cmd
    send_to_sign(cmd, "marquee.message", "#{cmd['text']} (#{params[:color].presence || 'Orange'}, x#{cmd['repeat']})",
                 "Sent. It goes up as soon as anything already showing finishes.")
  end

  def preset
    preset = Marquee.preset(params[:key])
    return redirect_to(marquee_path, alert: "That button does not exist.") unless preset
    send_to_sign(preset.command, "marquee.preset", preset.label, "#{preset.label}: on the sign now.")
  end

  def brightness
    label = Marquee::BRIGHTNESS.key?(params[:level]) ? params[:level] : nil
    return redirect_to(marquee_path, alert: "Pick Low, Normal or Bright.") unless label
    send_to_sign({ "brightness" => Marquee::BRIGHTNESS[label] }, "marquee.brightness", label,
                 "Brightness set to #{label.downcase}.")
  end

  def update_rotation
    current = client.rotation
    extras = Marquee::Rotation.from_panel(current).extras
    @rotation = Marquee::Rotation.from_params(params.fetch(:rotation, {}), extras: extras)
    unless @rotation.valid?
      return redirect_to(marquee_path, alert: ERB::Util.html_escape(@rotation.errors.full_messages.to_sentence))
    end
    client.set_rotation(@rotation.to_panel)
    audit_event("marquee.rotation", nil, @rotation.to_panel.to_json)
    redirect_to marquee_path, notice: "Saved. The sign shows the new mix from its next turn."
  rescue Marquee::Client::Error => e
    redirect_to marquee_path, alert: not_reached(e)
  end

  def poll
    send_to_sign(nil, "marquee.poll", "check lab status", "The sign is checking whether the lab is open.") do
      client.poll_status
    end
  end

  def restart
    send_to_sign(nil, "marquee.restart", "restart", "The sign is restarting. It is back in about ten seconds.") do
      client.reboot
    end
  end

  private

  def require_use
    authorize! :use, :marquee
  end

  def require_manage
    authorize! :manage, :marquee
  end

  def client
    @client ||= Marquee::Client.new
  end

  # For the frames: the block's result, or nil with @error set. A frame must
  # always render something, whatever went wrong.
  def frame_call
    yield
  rescue Marquee::Client::Error => e
    @error = e.message
    nil
  rescue StandardError => e
    Rails.logger.error "marquee frame: #{e.class}: #{e.message}"
    @error = "something went wrong reading the sign"
    nil
  end

  # Sends cmd (or runs the block), records it, and goes back to the page with
  # what happened. The flash is rendered as HTML, so nothing a member typed
  # goes into it.
  def send_to_sign(cmd, event_type, summary, done)
    block_given? ? yield : client.command(cmd)
    audit_event(event_type, nil, summary)
    redirect_to marquee_path, notice: done
  rescue Marquee::Client::Error => e
    redirect_to marquee_path, alert: not_reached(e)
  end

  def not_reached(error)
    reason = error.is_a?(Marquee::Client::Unreachable) ? "The sign did not answer" : "The sign said no"
    ERB::Util.html_escape("#{reason}: #{error.message}. Nothing changed.")
  end
end
