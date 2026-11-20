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

  # "+12%" or "-3%", or n/a.
  def laser_change(value)
    return tag.span("n/a", class: "muted") if value.nil?
    tag.span("#{"+" if value.positive?}#{laser_number(value)}%", class: (value < -2 ? "down" : value > 2 ? "up" : nil))
  end

  private

  def grid_line(from, to, at, label)
    safe_join([tag.line(class: "grid", x1: from, x2: to, y1: at.round(1), y2: at.round(1)),
               tag.text(label, x: from - 8, y: (at + 4).round(1), "text-anchor": "end")])
  end
end
