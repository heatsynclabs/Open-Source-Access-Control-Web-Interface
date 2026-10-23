class AuditEventsController < ApplicationController
  before_filter :authenticate_user!
  authorize_resource :class => "AuditEvent"   # admins only, per ability.rb
  layout 'resources'

  def index
    @events = AuditEvent.recent

    # optional filters (all admin-only)
    @events = @events.where(:event_type => params[:event_type]) if params[:event_type].present?
    if params[:affected_user_id].present?
      @events = @events.where(:affected_user_id => params[:affected_user_id])
    end
    if params[:editor_id].present?
      @events = @events.where(:editor_id => params[:editor_id])
    end

    @events = @events.limit(params[:all] ? 5000 : 500)

    # names for display without an N+1: one lookup for every user referenced
    ids = (@events.map(&:editor_id) + @events.map(&:affected_user_id)).compact.uniq
    @user_names = {}
    User.where(:id => ids).select("id, name").each { |u| @user_names[u.id] = u.name }

    @event_types = AuditEvent.select("DISTINCT event_type").map(&:event_type).compact.sort
  end
end
