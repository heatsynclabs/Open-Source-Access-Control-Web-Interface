# Formatting and the two drawn charts of the Laser page (a power against
# speed scatter and the energy law), which Chartkick cannot draw: plain SVG,
# coloured by the site's tokens, with a native tooltip on every mark.
module LaserHelper
  RELIABILITY_TONES = { "good" => :ok, "mid" => :warn, "poor" => :err }.freeze
  LAW_LINES = [["Plywood / wood", "Plywood", "law-plywood"], ["Acrylic", "Acrylic", "law-acrylic"], ["MDF / hardboard", "MDF", "law-mdf"]].freeze

  # 60, or 2.5: whole numbers without a decimal point (the explorer's f0, f1).
  def laser_number(value, digits = 0)
    return "" if value.nil?
    rounded = value.round(digits)
    rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
  end

  def laser_reliability_chip(reliability)
    key, label = reliability
    render ChipComponent.new(label, tone: RELIABILITY_TONES[key], dot: key != "thin")
  end

  # A bar split into jobs that worked, partly worked and failed.
  def laser_results_bar(counts, total)
    parts = { "ok" => counts["success"], "cond" => counts["conditional"], "bad" => counts["fail"] }
    label = "#{counts["success"]} worked, #{counts["conditional"]} partly, #{counts["fail"]} failed"
    tag.div(class: "laser-bar", role: "img", "aria-label": label) do
      safe_join(parts.map { |css, n| tag.i(class: css, style: "width: #{(100.0 * n.to_i / [total, 1].max).round(2)}%") })
    end
  end

  # Every power and speed tried for one setting: speed on a log scale, dot
  # size by jobs, colour by the worst outcome.
  def laser_scatter(points)
    return "" if points.empty?
    w, h, l, r, t, b = 840, 320, 46, 14, 14, 40
    speeds = points.map { |p| p[:speed] }
    lo, hi = [1, speeds.min * 0.7].max, speeds.max * 1.4
    lo, hi = lo / 2, hi * 2 if hi / lo < 4
    x = ->(v) { l + (Math.log(v) - Math.log(lo)) / (Math.log(hi) - Math.log(lo)) * (w - l - r) }
    y = ->(v) { t + (100 - v) / 100.0 * (h - t - b) }
    ticks = [1, 2, 3, 5, 7, 10, 15, 20, 30, 50, 70, 100, 150, 200, 300, 400, 600, 1000, 1500].select { |v| v.between?(lo, hi) }
      .each_with_object([]) { |v, kept| kept << v if kept.empty? || x.(v) - x.(kept.last) > 40 }
    most = points.map { |p| p[:n] }.max
    marks = [0, 25, 50, 75, 100].map { |v| grid_line(l, w - r, y.(v), v) }
    marks += ticks.map { |v| tag.text(v, x: x.(v).round(1), y: h - b + 16, "text-anchor": "middle") }
    marks << tag.text("Speed mm/s", class: "axis", x: (l + w - r) / 2, y: h - 6, "text-anchor": "middle")
    marks << tag.text("Power %", class: "axis", transform: "translate(12 #{(t + h - b) / 2}) rotate(-90)", "text-anchor": "middle")
    marks += points.map do |p|
      tone = p[:fail] ? "bad" : p[:conditional] ? "cond" : "ok"
      tip = "#{laser_number(p[:power])}% at #{laser_number(p[:speed])} mm/s: #{p[:n]} job#{"s" if p[:n] > 1}, " \
            "#{p[:success].to_i} worked, #{p[:conditional].to_i} partly, #{p[:fail].to_i} failed"
      tag.circle(tag.title(tip), class: tone, cx: x.(p[:speed]).round(1), cy: y.(p[:power]).round(1), r: (5 + Math.sqrt(p[:n].to_f / most) * 14).round(1))
    end
    tag.svg(safe_join(marks), class: "laser-chart", viewBox: "0 0 #{w} #{h}", role: "img", "aria-label": "Power against speed for every setting tried")
  end

  # The energy law: fitted lines for plywood, acrylic and MDF, with the
  # median of logged jobs at each thickness as dots.
  def laser_law_chart(math)
    w, h, l, r, t, b = 860, 300, 44, 70, 14, 40
    x = ->(v) { l + v / 14.0 * (w - l - r) }
    y = ->(v) { t + (1 - [v, 26].min / 26.0) * (h - t - b) }
    energy = ->(material, mm) { math[:k][material] * mm**math[:b] }
    marks = (0..25).step(5).map { |v| grid_line(l, w - r, y.(v), v) }
    marks += (0..14).step(2).map { |v| tag.text(v, x: x.(v), y: h - b + 16, "text-anchor": "middle") }
    marks << tag.text("Thickness mm", class: "axis", x: (l + w - r) / 2, y: h - 6, "text-anchor": "middle")
    marks << tag.text("J per mm", class: "axis", transform: "translate(12 #{(t + h - b) / 2}) rotate(-90)", "text-anchor": "middle")
    LAW_LINES.each_with_index do |(material, label, css), i|
      line = (2..28).map { |half| mm = half / 2.0; "#{x.(mm).round(1)},#{y.(energy.(material, mm)).round(1)}" }.join(" ")
      marks << tag.polyline(class: css, points: line)
      marks << tag.text(label, class: "end-label", x: x.(14) + 6, y: y.(energy.(material, 14)) + [4, -3, 13][i])
      marks += math[:observed].fetch(material, []).map do |mm, median, n|
        tag.circle(tag.title("#{label} #{laser_number(mm, 1)} mm: median #{median} J/mm from #{n} jobs"), class: css,
                   cx: x.(mm).round(1), cy: y.(median).round(1), r: (3 + [6, Math.sqrt(n) / 3].min).round(1))
      end
    end
    tag.svg(safe_join(marks), class: "laser-chart", viewBox: "0 0 #{w} #{h}", role: "img", "aria-label": "Energy needed against thickness for plywood, acrylic and MDF")
  end

  # Power / speed that 3 mm plywood needed, by half year, with the optics
  # work as dashed lines and each point's typical setting under it.
  def laser_drift_chart(drift)
    halves = drift.keys
    values = drift.values.compact.map { |v| v[:ratio] }
    return "" if values.empty?
    w, h, l, r, t, b = 860, 240, 30, 16, 24, 30
    top = values.max * 1.4
    first_year = halves.first.to_i
    x = ->(i) { l + (i + 0.5) * (w - l - r) / halves.size }
    y = ->(v) { t + (1 - v / top) * (h - t - b) }
    marks = (0..top.floor).step(2).map { |v| grid_line(l, w - r, y.(v), v) }
    marks += optics_lines(stagger: true) { |day| l + ((day.year - first_year) * 2 + (day.month - 1) / 6.0) * (w - l - r) / halves.size }.call(t + 6, h - b)
    points = halves.each_with_index.filter_map { |half, i| [i, drift[half]] if drift[half] }
    marks << tag.polyline(class: "trend", points: points.map { |i, v| "#{x.(i).round(1)},#{y.(v[:ratio]).round(1)}" }.join(" "))
    halves.each_with_index { |half, i| marks << tag.text(half, x: x.(i).round(1), y: h - b + 18, "text-anchor": "middle") }
    points.each do |i, v|
      marks << tag.circle(tag.title("#{halves[i]}: #{v[:ratio]} (#{laser_number(v[:power])}% at #{laser_number(v[:speed])} mm/s)"), class: "point", cx: x.(i).round(1), cy: y.(v[:ratio]).round(1), r: 6)
      marks << tag.text("#{laser_number(v[:power])}/#{laser_number(v[:speed])}", class: "point-label", x: (x.(i) - 10).round(1), y: (y.(v[:ratio]) + 22).round(1), "text-anchor": "middle")
    end
    tag.svg(safe_join(marks), class: "laser-chart", viewBox: "0 0 #{w} #{h}", role: "img", "aria-label": "Power to speed ratio for 3 mm plywood over time")
  end

  # The energy index by quarter (one vote per person), 1.00 dashed, optics
  # work as dashed lines.
  def laser_index_chart(quarters)
    return "" if quarters.empty?
    w, h, l, r, t, b, lo, hi = 860, 250, 40, 14, 30, 30, 0.7, 1.3
    x = ->(i) { l + (i + 0.5) * (w - l - r) / quarters.size }
    y = ->(v) { t + (hi - v.clamp(lo, hi)) / (hi - lo) * (h - t - b) }
    marks = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3].map do |v|
      safe_join([tag.line(class: (v == 1.0 ? "baseline" : "grid"), x1: l, x2: w - r, y1: y.(v).round(1), y2: y.(v).round(1)),
                 tag.text(format("%.1f", v), x: l - 8, y: (y.(v) + 4).round(1), "text-anchor": "end")])
    end
    names = quarters.map { |q| q[:quarter] }
    position = lambda do |day|
      i = names.index("#{day.year}Q#{(day.month - 1) / 3 + 1}")
      i && l + (i + ((day.month - 1) % 3 + day.day / 31.0) / 3) * (w - l - r) / quarters.size
    end
    marks += optics_lines(stagger: true, &position).call(t, h - b)
    marks << tag.polyline(class: "trend", points: quarters.each_with_index.map { |q, i| "#{x.(i).round(1)},#{y.(q[:vote]).round(1)}" }.join(" "))
    quarters.each_with_index do |q, i|
      marks << tag.circle(tag.title("#{q[:quarter]}: #{q[:vote]} from #{q[:people]} people, #{q[:n]} cuts"), class: "point", cx: x.(i).round(1), cy: y.(q[:vote]).round(1), r: 5)
      marks << tag.text(q[:quarter].sub("Q", " Q"), x: x.(i).round(1), y: h - b + 18, "text-anchor": "middle") if i.even?
    end
    tag.svg(safe_join(marks), class: "laser-chart", viewBox: "0 0 #{w} #{h}", role: "img", "aria-label": "Energy index by quarter")
  end

  # "+12%" or "-3%", or n/a.
  def laser_change(value)
    return tag.span("n/a", class: "muted") if value.nil?
    tag.span("#{"+" if value.positive?}#{laser_number(value)}%", class: (value < -2 ? "down" : value > 2 ? "up" : nil))
  end

  private

  # Dashed lines for the optics work in Laser::Model::OPTICS, at the x the
  # block gives for a date (nil: off the chart), labelled at the top.
  def optics_lines(stagger: false, &x_of)
    lambda do |top, bottom|
      Laser::Model::OPTICS.each_with_index.flat_map do |(day, label), i|
        at = x_of.call(day) or next []
        [tag.line(class: "optics", x1: at.round(1), x2: at.round(1), y1: top - 6, y2: bottom),
         tag.text(label, class: "optics-label", x: (at - 4).round(1), y: top - 10 - (stagger ? (i % 2) * 11 : 0), "text-anchor": "end")]
      end
    end
  end

  def grid_line(from, to, at, label)
    safe_join([tag.line(class: "grid", x1: from, x2: to, y1: at.round(1), y2: at.round(1)),
               tag.text(label, x: from - 8, y: (at + 4).round(1), "text-anchor": "end")])
  end
end
