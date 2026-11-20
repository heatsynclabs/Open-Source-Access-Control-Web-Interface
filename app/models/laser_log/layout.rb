module LaserLog
  # Puts the rows of each log sheet in the current form's column order, so
  # one LaserLog::Cleaner cleans them all. The current forms (both machines
  # share one layout) pass through; the old forms are read by header name:
  #   - neither old form asks "Did you use CUTTING / ENGRAVING?": a job cut or
  #     engraved when it has that power and speed;
  #   - the old large form's thickness is a number of mm, its material free
  #     text, put in the current form's terms with OLD_MATERIALS (first match
  #     wins); it never asked for results, so they are left blank ("unknown");
  #   - the old mini form already used the current form's materials, with a
  #     few older spellings.
  # Each row comes back with what the cleaner should keep as logged, where it
  # differs from what it reads: { material_raw:, notes: }.
  module Layout
    OLD_MATERIALS = [
      ["OTHER", /pumpkin|graham|chocolate|steak|food|cookie|bread|tortilla|slate|tombstone|mylar|pet sheet|cork/i],
      ["Polystyrene", /\bhips\b|high impact|^styrene/i],
      ["Styrofoam", /styrofoam|xps|foamular|insulation|polystyrene|blue board|pink foam/i],
      ["Foam Core (Non-PVC)", /fo[ar]m ?core|foam ?board|foamcore/i],
      ["EVA Foam", /\beva\b|craft foam|foam sheet/i],
      ["Polyethylene (PE)", /polyeth|\bhdpe\b|\bldpe\b|\bpe foam\b|toolbox/i],
      ["Rubber, Rubber Stamp", /rubber|stamp/i],
      ["Leather", /leather|pigskin|suede|cowhide/i],
      ["Cloth", /cloth|fabric|feld?t|denim|canvas|cotton|fleece|nylon|polyester|wool|rayon|linen/i],
      ["Glass", /glass/i],
      ["Mirror (backside)", /mirror/i],
      ["Anodized Aluminum", /anodi[sz]ed|alumin/i],
      ["Stainless Steel (Cerdec Coated)", /stainless|cermark|cerdec/i],
      ["Stone (Marble, Granite, etc.)", /stone|granite|marble|ceramic|clay|brick|concrete/i],
      ["Tile", /\btile/i],
      ["Delrin Seals (Acetal)", /d[ae]lrin|acetal/i],
      ["ABS", /\babs\b/i],
      ["Acrylic (Plexiglas, Lucite)", /acrylic|plexi|lucite|perspex|acryllic/i],
      ["Laserable Plastic", /laserable plastic|laminate|two.?tone|engraving plastic|rowmark/i],
      ["Melamine", /melamine|white ?board|dry erase/i],
      ["MDF (Medium Density Fibreboard)", /\bmdf\b|\bhdf\b|masonite|hard ?b[a-z]{1,4}d|fibre|fiber ?board|particle|chalk ?board|thrifty white/i],
      ["Cardboard (Posterboard)", /poster ?board|chip ?board/i],
      ["Cardboard (Coorrugated)", /cardboard|corrugat|carboard/i],
      ["Mat Board", /mat ?board/i],
      ["Paper (cardstock)", /card ?stock/i],
      ["Paper", /paper/i],
      ["Plywood", /ply|birch|berch|baltic|lauan|luan|underlayment/i],
      ["Softwood (Balsa, Basswood, Pine)", /basswood|balsa|pine|cedar|spruce|fir\b/i],
      ["Hardwood (Cherry, Alder, Walnut, Poplar)", /hardwood|mahogany|maple|walnut|cherry|oak|alder|poplar|ash\b|hickory|padauk|purple ?heart|zebra|teak|blackwoo|mesquite|ebony|rosewood/i],
      ["Wood", /wood|veneer|lumber|pencil|dowel|popsicle|craft stick|bark|bamboo|olive/i],
    ].freeze
    OLD_MINI_NAMES = { "Cardboard (Corrugated)" => "Cardboard (Coorrugated)", "Cardboard" => "Cardboard (Coorrugated)" }.freeze

    module_function

    # [[cells, kept], ...] for the sheet's rows after the header.
    def rows(csv_text, layout)
      table = CSV.parse(csv_text)
      header = table.first.to_a.map { |h| h.to_s.strip }
      raise Error, "the sheet does not look like a laser log" unless header.first == "Timestamp"
      return table.drop(1).map { |row| [row, {}] } if layout == :form
      table.drop(1).map do |row|
        f = ->(start) { row[header.index { |h| h.start_with?(start) } || header.size].to_s.strip }
        send(layout, f)
      end
    end

    def old_large(f)
      logged = f.("Material")
      material = form_material(logged)
      thickness = f.("Thickness")
      thickness = "#{thickness} mm" if thickness.match?(/\A\d+(\.\d+)?\z/)
      notes = f.("Project Notes")
      cells = form_row(f, material: material, thickness: thickness, who: f.("Your Name"), runtime: f.("Laser run time"),
                       clean: f.("Was the laser clean"), cleaned: f.("Did you clean"), cut_passes: f.("Number of passes"),
                       eng_passes: "", gap: f.("Engraving Scan Gap"), result: "", notes: "#{notes} #{logged}".strip, software: "")
      [cells, { material_raw: logged, notes: notes }]
    end

    def old_mini(f)
      logged = f.("Material")
      cells = form_row(f, material: OLD_MINI_NAMES.fetch(logged, logged), thickness: f.("Thickness"), who: f.("Name"),
                       runtime: f.("Laser Run Time"), clean: f.("Was the machine clean"), cleaned: f.("Did you clean"),
                       cut_passes: f.("Cutting Number of Passes"), eng_passes: f.("Engraving Number of Passes"),
                       gap: f.("Engraving Gap"), result: f.("Results"), notes: f.("Project Notes"), software: f.("Software Notes"))
      [cells, { material_raw: logged }]
    end

    def form_row(f, material:, thickness:, who:, runtime:, clean:, cleaned:, cut_passes:, eng_passes:, gap:, result:, notes:, software:)
      cut = f.("Cutting Power").present? && f.("Cutting Speed").present? ? "Yes" : "No"
      engrave = f.("Engraving Power").present? && f.("Engraving Speed").present? ? "Yes" : "No"
      [f.("Timestamp"), f.("Start Time"), "", f.("Project Title"), who, runtime, "", clean, "", cleaned, material, thickness,
       cut, f.("Cutting Power"), f.("Cutting Speed"), cut_passes, engrave, f.("Engraving Power"), f.("Engraving Speed"), eng_passes,
       gap, result, notes, f.("Machine Notes"), software]
    end

    def form_material(text)
      OLD_MATERIALS.find { |_name, pattern| text.match?(pattern) }&.first || "OTHER"
    end
  end
end
