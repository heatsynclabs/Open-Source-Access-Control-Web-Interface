# The lab's laser cutters' settings guide, for signed-in members: what power
# and speed worked for each material and thickness, what goes wrong, the
# laser math, a printable cheat sheet and the log itself, for one machine at a
# time (MACHINES; the large 80 W by default), with the mini's tube reading
# (Laser::Tube) above every view. Built from each machine's
# current log form (LaserJob, rebuilt nightly by laser:sync); its old form
# shows beside it as history (what people used then) and in the log, never
# in "what worked". Nothing here names the person who logged a job. See
# docs/laser.md.
class LaserController < ApplicationController
  before_action :authenticate_user!

  VIEWS = {
    "find" => "Find a setting", "all" => "All settings", "trouble" => "What goes wrong",
    "math" => "Laser math", "sheet" => "Cheat sheet", "log" => "The log",
  }.freeze
  LOG_PAGE = 50
  # paper => [label, width in, height in]; the 11 x 17 in cheat sheet is
  # scaled to fit one page of it
  PAPERS = {
    "letter" => ["Letter", 8.5, 11], "a4" => ["A4", 8.27, 11.69], "tabloid" => ["Tabloid 11 x 17", 11, 17],
    "a3" => ["A3", 11.69, 16.54], "poster" => ["Poster 18 x 24", 18, 24], "poster24" => ["Poster 24 x 36", 24, 36],
  }.freeze

  helper_method :laser_at

  def show
    @view = VIEWS.key?(params[:view]) ? params[:view] : "find"
    @machine = LaserJob::MACHINES.key?(params[:machine]) ? params[:machine] : "large"
    return render(:empty) unless LaserJob.available? && LaserJob.where(machine: @machine, source: LaserJob::FORM).exists?
    @synced_at = LaserJob.synced_at
    @jobs = Laser::Log.jobs(@machine)
    @earlier = Laser::Log.jobs(@machine, LaserJob::OLD)
    @settings = Laser::Settings.new(@jobs)
    @earlier_settings = Laser::Settings.new(@earlier)
    @tube = Laser::Tube.summary(@machine)
    send("#{@view}_view")
  end

  private

  # laser_path for this machine (the large laser's links carry no machine).
  def laser_at(**options)
    laser_path(**options, machine: (@machine unless @machine == "large"))
  end

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
    @trouble = Laser::Trouble.new(@jobs, earlier: @earlier)
  end

  def math_view
    @math = Laser::Model.summary(@machine)
  end

  def sheet_view
    @paper = PAPERS.key?(params[:paper]) ? params[:paper] : "tabloid"
    @sheet = @settings.sheet
    @trouble = Laser::Trouble.new(@jobs)
  end

  def log_view
    switch = @jobs.first.date.year
    @logs = { "form" => "Current form (#{switch} on)" }
    @logs["old"] = "Old form (#{@earlier.first.date.year} to #{switch})" if @earlier.any?
    everything = @earlier + @jobs
    @materials = everything.map(&:material).uniq.sort_by { |m| LaserLog::Cleaner::FAMILY.keys.index(m) || 99 }
    query = params[:q].to_s.downcase.strip
    from = { "form" => @jobs, "old" => @earlier }.fetch(params[:log], everything)
    found = from.select do |job|
      (params[:material].blank? || job.material == params[:material]) &&
        (params[:result].blank? || job.result == params[:result]) &&
        (query.empty? || [job.title, job.notes, job.machine_notes, job.software_notes, job.material_raw].join(" ").downcase.include?(query))
    end.sort_by { |job| [job.date, job.source == LaserJob::FORM ? 1 : 0, job.id] }.reverse
    @shown = [params[:shown].to_i, LOG_PAGE].max
    @found = found.size
    @log = found.first(@shown)
  end
end
