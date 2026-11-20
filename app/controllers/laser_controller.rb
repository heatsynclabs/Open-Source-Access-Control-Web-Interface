# The large 80 W laser's settings guide, for signed-in members: what power
# and speed worked for each material and thickness, what goes wrong, the
# laser math, a printable cheat sheet and the log itself. Built from the
# laser log form (LaserJob, rebuilt nightly by laser:sync). Nothing here
# names the person who logged a job. See docs/laser.md.
class LaserController < ApplicationController
  before_action :authenticate_user!

  VIEWS = {
    "find" => "Find a setting", "all" => "All settings", "trouble" => "What goes wrong",
    "math" => "Laser math", "sheet" => "Cheat sheet", "log" => "The log",
  }.freeze
  LOG_PAGE = 50
  PAPERS = {
    "letter" => ["Letter", "8.5in 11in"], "a4" => ["A4", "210mm 297mm"], "tabloid" => ["Tabloid 11 x 17", "11in 17in"],
    "a3" => ["A3", "297mm 420mm"], "poster" => ["Poster 18 x 24", "18in 24in"],
  }.freeze

  def show
    @view = VIEWS.key?(params[:view]) ? params[:view] : "find"
    return render(:empty) unless LaserJob.available? && LaserJob.exists?
    @synced_at = LaserJob.synced_at
    @jobs = Laser::Log.jobs
    @settings = Laser::Settings.new(@jobs)
    send("#{@view}_view")
  end

  private

  def find_view
    @material, @op, @bucket = @settings.choose(params[:material], params[:op], params[:bucket])
    @rows = @settings.rows_for(@material, @bucket, @op)
    @stats = @settings.stats(@rows, @op)
    @reliability = @settings.reliability(@stats)
  end

  def all_view
    @op = Laser::Settings::OPS.key?(params[:op]) ? params[:op] : "cut"
    @table = @settings.table(@op)
  end

  def trouble_view
    @trouble = Laser::Trouble.new(@jobs)
  end

  def math_view
    @math = Laser::Model.summary
  end

  def sheet_view
    @paper = PAPERS.key?(params[:paper]) ? params[:paper] : "tabloid"
    @sheet = @settings.sheet
    @trouble = Laser::Trouble.new(@jobs)
  end

  def log_view
    @materials = @jobs.map(&:material).uniq.sort_by { |m| LaserLog::Cleaner::FAMILY.keys.index(m) || 99 }
    query = params[:q].to_s.downcase.strip
    found = @jobs.select do |job|
      (params[:material].blank? || job.material == params[:material]) &&
        (params[:result].blank? || job.result == params[:result]) &&
        (query.empty? || [job.title, job.notes, job.machine_notes, job.software_notes, job.material_raw].join(" ").downcase.include?(query))
    end.reverse
    @shown = [params[:shown].to_i, LOG_PAGE].max
    @found = found.size
    @log = found.first(@shown)
  end
end
