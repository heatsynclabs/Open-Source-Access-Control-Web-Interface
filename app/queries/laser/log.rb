module Laser
  # One laser's jobs (LaserJob::MACHINES), from one log (LaserJob::FORM by
  # default, LaserJob::OLD, or nil for both), as plain values for the Laser
  # page's arithmetic (numbers as floats), oldest first, read once per request.
  class Log
    Job = Data.define(:machine, :source, :id, :date, :person, :title, :material_raw, :material, :family, :mm, :bucket, :cut_op,
                      :cut_power, :cut_speed, :cut_passes, :eng_mode, :eng_power, :eng_speed, :eng_passes, :eng_gap,
                      :result, :result_raw, :issues, :minutes, :clean_start, :notes, :machine_notes, :software_notes,
                      :fixes) do
      def success? = result == "success"
      def settings? = cut_op.present? || eng_mode.present?
      def passes = cut_passes || 1
    end

    FLOATS = %i[mm cut_power cut_speed cut_passes eng_power eng_speed eng_passes eng_gap minutes].freeze

    def self.jobs(machine, source = LaserJob::FORM)
      scope = LaserJob.where(machine: machine)
      scope = scope.where(source: source) if source
      scope.order(:logged_at, :sheet_row).map do |job|
        values = FLOATS.to_h { |field| [field, job[field]&.to_f] }
        Job.new(machine: job.machine, source: job.source, id: job.sheet_row, date: job.logged_on, person: job.person_key, title: job.title,
                material_raw: job.material_raw, material: job.material, family: job.family, bucket: job.bucket,
                cut_op: job.cut_op, eng_mode: job.eng_mode, result: job.result, result_raw: job.result_raw,
                issues: job.issue_list, clean_start: job.clean_start, notes: job.notes, machine_notes: job.machine_notes,
                software_notes: job.software_notes, fixes: job.fix_list, **values)
      end
    end
  end
end
