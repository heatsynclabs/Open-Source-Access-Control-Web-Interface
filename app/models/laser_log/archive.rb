require "csv"

module LaserLog
  # The large laser's earlier log: an older form, 2013-10-29 to 2020-06-20,
  # whose settings a member uploaded to the old wiki in June 2020
  # (large-laser-log.xlsx). The operations folder's data/scripts/laser.py turns
  # it into db/archive/large-laser-log-2013-2020.csv, with each free-text
  # material put in the current form's terms. It has dates, materials,
  # thickness and settings only: no names, results, passes, run time or
  # notes. Each row is cleaned by LaserLog::Cleaner like a form row and kept
  # as source LaserJob::EARLIER; laser:sync loads it when it is missing or
  # the file has changed.
  class Archive
    FILE = Rails.root.join("db/archive/large-laser-log-2013-2020.csv")

    def jobs
      cleaner = Cleaner.new
      now = Time.current
      CSV.read(FILE, headers: true).each_with_index.filter_map do |row, i|
        cut = row["cut_power"].present? && row["cut_speed"].present? ? "Yes" : "No"
        engrave = row["engrave_power"].present? && row["engrave_speed"].present? ? "Yes" : "No"
        # In the form's column order. The material as logged goes in as the
        # note, where the cleaner's note rules look (bamboo, masonite...).
        form_row = [row["timestamp"], "", "", "", "", "", "", "", "", "", row["material"], row["thickness"],
                    cut, row["cut_power"], row["cut_speed"], "", engrave, row["engrave_power"], row["engrave_speed"], "",
                    row["engrave_gap"], "", row["material_logged"], "", ""]
        attributes, = cleaner.call(form_row, i + 2)
        attributes&.merge(source: LaserJob::EARLIER, material_raw: row["material_logged"].to_s, notes: "", person_key: "",
                          created_at: now, updated_at: now)
      end
    end

    def loaded?
      LaserJob.where(source: LaserJob::EARLIER).count == CSV.read(FILE, headers: true).size
    end

    def load!
      records = jobs
      LaserJob.transaction do
        LaserJob.where(source: LaserJob::EARLIER).delete_all
        LaserJob.insert_all!(records)
      end
      Rails.cache.delete_matched("laser") rescue nil
      records.size
    end
  end
end
