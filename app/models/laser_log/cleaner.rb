module LaserLog
  # Turns one row of the laser log form into a clean job, the same way the
  # laser explorer's process_laser_log.py does, recording every repair in
  # :fixes. The form accepts anything, so:
  #   - materials logged under different names fold together (Wood and
  #     Plywood, OTHER with a note that says what it was);
  #   - thickness text becomes millimetres and a bucket;
  #   - power and speed typed into each other's box are swapped back;
  #   - engrave settings typed in the cut boxes become a "score" (vector mark);
  #   - impossible pass counts, and scan gaps over 0.5 mm, are dropped;
  #   - glass settings typed in the cut boxes are read as engrave;
  #   - free-text results become success, conditional or fail.
  # The name on the form is read here (one material rule depends on it) and
  # never returned.
  class Cleaner
    COLUMNS = 25

    FAMILY = {
      "Plywood / wood" => "Wood", "Softwood (basswood, balsa, pine)" => "Wood",
      "Hardwood" => "Wood", "Bamboo" => "Wood", "MDF / hardboard" => "Wood",
      "Melamine / whiteboard" => "Wood",
      "Acrylic" => "Plastic", "Delrin (acetal)" => "Plastic", "Laserable plastic" => "Plastic",
      "Polystyrene sheet (HIPS)" => "Plastic", "Polyethylene sheet" => "Plastic",
      "ABS" => "Plastic", "PET / Mylar film" => "Plastic",
      "Paper / cardstock" => "Paper and board", "Corrugated cardboard" => "Paper and board",
      "Mat board" => "Paper and board", "Foam core" => "Paper and board",
      "EVA foam" => "Foam", "PE foam (toolbox)" => "Foam", "XPS foam (polystyrene)" => "Foam",
      "Leather" => "Soft goods", "Cloth" => "Soft goods", "Rubber (stamp, gasket)" => "Soft goods",
      "Anodized aluminum" => "Hard surface", "Glass" => "Hard surface",
      "Stone / slate / tile" => "Hard surface", "Cast stone (manufactured)" => "Hard surface",
      "Stainless (Cerdec coated)" => "Hard surface", "Mirror (backside)" => "Hard surface",
      "Food" => "Other", "Other / unknown" => "Other",
    }.freeze

    # Materials where a fast, low power vector pass really is a through cut.
    THIN = ["Paper / cardstock", "Corrugated cardboard", "Foam core", "EVA foam", "PE foam (toolbox)",
            "XPS foam (polystyrene)", "Cloth", "Leather", "Food", "Other / unknown", "PET / Mylar film",
            "Rubber (stamp, gasket)"].freeze

    RAW_MAP = {
      "Acrylic (Plexiglas, Lucite)" => "Acrylic",
      "Plywood" => "Plywood / wood", "Wood" => "Plywood / wood",
      "Softwood (Balsa, Basswood, Pine)" => "Softwood (basswood, balsa, pine)",
      "Hardwood (Cherry, Alder, Walnut, Poplar)" => "Hardwood",
      "MDF (Medium Density Fibreboard)" => "MDF / hardboard",
      "Melamine" => "Melamine / whiteboard",
      "Paper" => "Paper / cardstock", "Paper (cardstock)" => "Paper / cardstock",
      "Cardboard (Coorrugated)" => "Corrugated cardboard",
      "Mat Board" => "Mat board", "Foam Core (Non-PVC)" => "Foam core",
      "EVA Foam" => "EVA foam", "Styrofoam" => "XPS foam (polystyrene)",
      "Leather" => "Leather", "Cloth" => "Cloth",
      "Rubber, Rubber Stamp" => "Rubber (stamp, gasket)",
      "Anodized Aluminum" => "Anodized aluminum", "Glass" => "Glass",
      "Stone (Marble, Granite, etc.)" => "Stone / slate / tile", "Tile" => "Stone / slate / tile",
      "Stainless Steel (Cerdec Coated)" => "Stainless (Cerdec coated)",
      "Mirror (backside)" => "Mirror (backside)",
      "Delrin Seals (Acetal)" => "Delrin (acetal)", "Laserable Plastic" => "Laserable plastic",
      "ABS" => "ABS",
    }.freeze
    MERGED_NAMES = ["Wood", "Paper", "Tile", "Styrofoam"].freeze

    # [largest mm, label]
    BUCKETS = [
      [1.5, "1 mm or less"], [2.5, "2 mm"], [3.5, "3 mm (1/8 in)"], [4.5, "4 mm"],
      [5.5, "5 mm"], [6.5, "6 mm (1/4 in)"], [8.5, "7 to 8 mm"],
      [10.5, "9 to 10 mm (3/8 in)"], [13.5, "12 to 13 mm (1/2 in)"],
      [25.5, "20 to 25 mm (1 in)"], [999, "35 to 50 mm (2 in)"],
    ].freeze
    BUCKET_ORDER = (BUCKETS.map(&:last) + ["Surface only", "Not stated"]).freeze

    # Hand corrections to the large laser's current form, keyed by its
    # timestamp text (Cleaner.new(overrides: false) for every other log).
    OVERRIDE = {
      "2/11/2023 17:07:48" => { cut_power: 45, why: "cut power 454 read as 45" },
      "2/15/2024 16:09:57" => { cut_op: "score", why: "note says light mark, not a cut" },
      "7/23/2026 15:38:02" => { cut_op: "score", why: "note says test, not through" },
    }.freeze

    # Large laser current-form rows logged as OTHER that were cast stone,
    # though neither title nor notes say so (found by hand, June 2022).
    CAST_STONE = ["6/1/2022 12:09:41", "6/1/2022 17:48:00", "6/2/2022 17:25:41",
                  "6/3/2022 10:44:23", "6/6/2022 18:50:49", "6/7/2022 13:08:04"].freeze

    # Keyword tags for what went wrong, approximate by nature (checked by hand
    # against every row that was not a success when they were written).
    ISSUES = [
      ["did not cut through", /(n[o']t|wouldn'?t|didn'?t|couldn'?t|can'?t|won'?t)[^.#]{0,40}(through|thru|penetrate|all the way|total thickness)|not cut (at all|on first)|barely|mostly cut through|struggled to cut|no longer work|not sure you can cut|more power and more passes|took \d passes|break (it )?apart|knife|too thick|cut \d+% of/],
      ["fire / burning", /fire|flame|burn|scorch|blowtorch|melt/],
      ["software / comms", /soft ?dog|soft stop|soft error|software|dongle|87%|communication|lasercut crashed|download|dxf files|immediate/],
      ["focus / alignment", /focus|focal|align|alinement|out of level|registration|uneven/],
      ["smoke / exhaust", /smoke|smoking|exhaust/],
      ["warped material", /warp|bowing|bowed/],
    ].freeze

    def initialize(overrides: true)
      @overrides = overrides ? OVERRIDE : {}
    end

    # The job's attributes (without person_key), and the name for the caller
    # to turn into a key; nil for a row with no readable timestamp. The row is
    # in the current form's column order (LaserLog::Layout turns the old
    # forms' rows into it).
    def call(row, sheet_row)
      cells = row.map { |cell| cell.to_s.strip }
      cells += [""] * (COLUMNS - cells.size) if cells.size < COLUMNS
      (stamp, _start, _finish, title, who, runtime, copies, clean_start, _dirty, cleaned_after, material_raw, thickness,
       cut, cut_power, cut_speed, cut_passes, engrave, eng_power, eng_speed, eng_passes, eng_gap, result_raw,
       notes, machine_notes, software_notes) = cells.first(COLUMNS)
      logged_at = parse_stamp(stamp) or return nil
      fixes = []
      if who.length > 60 # two rows had a repair note pasted over the name
        who = "(name overwritten)"
        fixes << "name field held a pasted note"
      end
      who = who.split.join(" ")
      mm, bucket = thickness_of(thickness)
      material, why = material_of(material_raw, mm, title, stamp, notes)
      fixes << "material: #{why}" if why

      override = @overrides.fetch(stamp, {})
      cut_setting = [nil] * 4
      if cut == "Yes"
        cut_setting = fix_cut(override.fetch(:cut_power) { number(cut_power) }, number(cut_speed), number(cut_passes), material, mm, fixes)
        cut_setting[3] = override[:cut_op] if cut_setting[3] && override.key?(:cut_op)
        fixes << override[:why] if override[:why]
      end
      eng_setting = [nil] * 4
      gap = nil
      if engrave == "Yes"
        eng_setting = fix_engrave(number(eng_power), number(eng_speed), number(eng_passes), fixes)
        gap = scan_gap(eng_gap) if eng_setting[0]
        fixes << "scan gap dropped" if eng_setting[0] && eng_gap.present? && gap.nil?
      end
      # Glass cannot be cut on a CO2 laser: settings in the cut boxes are the engrave.
      if material == "Glass" && cut_setting[3] && !eng_setting[0]
        power, speed, passes, = cut_setting
        eng_setting = [power, speed, passes, speed >= 100 ? "raster" : "slow"]
        cut_setting = [nil] * 4
        fixes.reject! { |fix| fix.include?("score") }
        fixes << "glass: cut boxes read as engrave"
      end
      result = result_of(result_raw)
      fixes << "free text result read as #{result}" if result_raw.present? && !%w[success fail].include?(result_raw.downcase) && result_raw.downcase != "conditional success"
      minutes = number(runtime)
      minutes = nil if minutes && (minutes > 600 || (runtime.start_with?("0") && runtime.length > 1))
      text = [result == "success" ? "" : result_raw, notes, machine_notes, software_notes].join(" ")

      attributes = {
        sheet_row: sheet_row, logged_at: logged_at, logged_on: logged_at.to_date, title: title,
        material_raw: material_raw, material: material, family: FAMILY.fetch(material),
        thickness_raw: thickness, mm: mm, bucket: bucket,
        cut_power: cut_setting[0], cut_speed: cut_setting[1], cut_passes: cut_setting[2], cut_op: cut_setting[3],
        eng_power: eng_setting[0], eng_speed: eng_setting[1], eng_passes: eng_setting[2], eng_mode: eng_setting[3],
        eng_gap: gap, result: result, result_raw: result_raw, issues: issues_of(result, text).join("; "),
        minutes: minutes, copies: number(copies), clean_start: clean_start, cleaned_after: cleaned_after,
        notes: notes, machine_notes: machine_notes, software_notes: software_notes, fixes: fixes.join("; "),
      }
      [attributes, who]
    end

    private

    def parse_stamp(text)
      Time.zone.strptime(text, "%m/%d/%Y %H:%M:%S")
    rescue ArgumentError
      nil
    end

    def number(text)
      text = text.to_s.strip
      return nil if text.empty?
      Float(text)
    rescue ArgumentError
      nil
    end

    def scan_gap(text)
      text = text.strip
      return nil if text.empty?
      text = "0.#{text[1..]}" if text.match?(/\A0\d+\z/) # "008" meant 0.08
      value = number(text)
      # 250, 300 and 20 are defaults or typos; 0.8 and 1 are almost surely 0.08 and 0.1
      value if value && value > 0 && value <= 0.5
    end

    def thickness_of(text)
      return [nil, "Surface only"] if text.start_with?("Surface")
      found = text.match(/\A(\d+(?:\.\d+)?)\s*mm/) or return [nil, "Not stated"]
      mm = found[1].to_f
      [mm, BUCKETS.find { |largest, _label| mm <= largest }.last]
    end

    def has?(text, *words)
      words.any? { |word| text.include?(word) }
    end

    def material_of(raw, mm, title, stamp, notes)
      text = "#{title} #{notes}".downcase
      if raw == "OTHER"
        return ["Food", "OTHER + note"] if has?(text, "pumpkin", "graham", "chocolate", "steak")
        return ["Stone / slate / tile", "OTHER + note"] if has?(text, "slate", "rock engrave")
        if (has?(text, "stone") && !has?(text, "tombstone")) || (@overrides.any? && CAST_STONE.include?(stamp))
          return ["Cast stone (manufactured)", "OTHER + note"]
        end
        return ["XPS foam (polystyrene)", "OTHER + note"] if has?(text, "polystyrene", "tombstone", "haunter") && !has?(text, "high impact")
        return ["Polystyrene sheet (HIPS)", "OTHER + note"] if has?(text, "high impact", "hips")
        return ["PE foam (toolbox)", "OTHER + note"] if has?(text, "polyeth", "toolbox foam", "tool box insert", "toolbox insert")
        return ["Melamine / whiteboard", "OTHER + note"] if has?(text, "dry erase", "white board", "whiteboard")
        return ["MDF / hardboard", "OTHER + note"] if has?(text, "masonite", "build-a-bot", "build a bot", "bartholomew")
        return ["PET / Mylar film", "OTHER + note"] if has?(text, "pet sheet", "mylar")
        return ["Plywood / wood", "OTHER + note"] if has?(text, "ukulele")
        return ["Rubber (stamp, gasket)", "OTHER + note"] if has?(text, "gasket")
        return ["Foam core", "OTHER + note"] if has?(text, "foam board")
        return ["Laserable plastic", "OTHER + note"] if has?(text, "host wings")
        return ["Other / unknown", nil]
      end
      if raw == "Polystyrene"
        return mm && mm <= 3 ? ["Polystyrene sheet (HIPS)", "thin polystyrene is sheet"] : ["XPS foam (polystyrene)", "polystyrene foam"]
      end
      if raw == "Polyethylene (PE)"
        return has?(text, "foam", "insert", "toolbox", "tool box") ? ["PE foam (toolbox)", "PE toolbox foam"] : ["Polyethylene sheet", nil]
      end
      if raw == "Cardboard (Posterboard)"
        return mm && mm >= 3 ? ["Corrugated cardboard", "thick posterboard"] : ["Paper / cardstock", "thin posterboard"]
      end
      return ["PE foam (toolbox)", "note says toolbox liner"] if raw == "Foam Core (Non-PVC)" && has?(text, "tool box liner")
      return ["Melamine / whiteboard", "note says whiteboard"] if raw == "MDF (Medium Density Fibreboard)" && has?(text, "thrifty white")
      return ["Bamboo", "note says bamboo"] if ["Wood", "Softwood (Balsa, Basswood, Pine)"].include?(raw) && has?(text, "bamboo")
      return ["Hardwood", "title says olivewood"] if raw == "Wood" && has?(text, "olivewood")
      return [RAW_MAP[raw], (MERGED_NAMES.include?(raw) ? "merged name" : nil)] if RAW_MAP.key?(raw)
      ["Other / unknown", nil]
    end

    # [power, speed, passes, op]; op is "cut", "score" or nil.
    def fix_cut(power, speed, passes, material, mm, fixes)
      return [nil] * 4 if power.nil? || speed.nil? || power <= 0 || speed <= 0
      if power > 100 && speed <= 100
        power, speed = speed, power
        fixes << "cut power/speed swapped"
      elsif power > 100
        return [nil] * 4
      end
      rigid = !THIN.include?(material) && !(mm && mm <= 1.5)
      op = "cut"
      if rigid
        if speed >= 100
          op = "score"
          fixes << "fast vector pass filed as score"
        elsif power <= 30 && speed >= 40 && speed < 100 && (mm.nil? || mm >= 3)
          power, speed = speed, power
          fixes << "cut power/speed swapped"
        elsif power <= 25 && speed < 40 && (mm.nil? || mm >= 3)
          op = "score"
          fixes << "low power vector pass filed as score"
        end
      end
      passes = clean_passes(passes, "cut", fixes)
      [power, speed, passes, op]
    end

    # [power, speed, passes, mode]; mode is "raster" (fast) or "slow".
    def fix_engrave(power, speed, passes, fixes)
      return [nil] * 4 if power.nil? || speed.nil? || power <= 0 || speed <= 0
      if power > 100 && speed <= 100
        power, speed = speed, power
        fixes << "engrave power/speed swapped"
      elsif power > 100
        return [nil] * 4
      end
      [power, speed, clean_passes(passes, "engrave", fixes), speed >= 100 ? "raster" : "slow"]
    end

    def clean_passes(passes, what, fixes)
      return 1 if passes.nil? || passes < 1
      return passes if passes <= 10
      fixes << "#{what} passes dropped"
      nil
    end

    def result_of(text)
      text = text.strip.downcase
      return "success" if text == "success" || text.start_with?("70 power") || text == "machine maintenance"
      return "fail" if text == "fail" || text == "defective layout"
      return "conditional" if text.present?
      "unknown"
    end

    def issues_of(result, text)
      return [] if result == "success"
      text = text.downcase.gsub("lightburn", "")
      ISSUES.filter_map { |name, pattern| name if text.match?(pattern) }
    end
  end
end
