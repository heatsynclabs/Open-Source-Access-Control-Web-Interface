# The map of where members live (analytics, Over the years): Arizona's real
# outline and counties (ArizonaMap, from US Census boundaries) with a dot per
# zone of ZIP codes (members_by_zone in lab_metrics), its area in step with
# the number of dues payers there and the number inside it. Two views: the
# whole state, and the Phoenix metro, where nearly everyone lives. Each metro
# zone has its own colour (the charts' palette, in order, .az-map --z1 to
# --z8); Pinal, Tucson and zones under 5 people (rings) are neutral.
module ZoneMapHelper
  # zone => [lat, lon, label side] at roughly the middle of its ZIP codes.
  ZONE_PLACES = {
    "West Valley" => [33.55, -112.27, :above], "Phoenix" => [33.49, -112.07, :left],
    "Scottsdale and Fountain Hills" => [33.57, -111.86, :above], "Tempe" => [33.39, -111.935, :left],
    "Mesa, downtown and west" => [33.405, -111.845, :above], "East Mesa" => [33.42, -111.68, :right],
    "Chandler" => [33.29, -111.86, :left], "Gilbert" => [33.32, -111.76, :below],
    "Pinal County" => [33.16, -111.56, :below], "Tucson and the south" => [32.22, -110.97, :right],
  }.freeze
  LAB_ZONE = "Mesa, downtown and west"
  # Towns on the state view for bearings (no data).
  TOWNS = { "Flagstaff" => [35.198, -111.651], "Yuma" => [32.693, -114.628], "Prescott" => [34.54, -112.469] }.freeze
  METRO_ZONES = (ZONE_PLACES.keys - ["Tucson and the south"]).freeze
  # County names on the metro view, for bearings.
  METRO_COUNTIES = { "Maricopa County" => [33.71, -112.42], "Pinal County" => [33.08, -111.62] }.freeze
  MAX_RADIUS = 24
  MIN_RADIUS = 11 # room for two digits

  # zones: { name => count, nil for fewer than 5 }
  def zone_map(zones)
    most = zones.slice(*ZONE_PLACES.keys).values.compact.max.to_f
    label = "Where members live: " + zones.map { |name, n| "#{name} #{n || "fewer than 5"}" }.join(", ")
    tag.div(class: "az-map", role: "img", "aria-label": label) do
      safe_join([zone_map_view("state", zones, most), zone_map_view("metro", zones, most)])
    end
  end

  private

  def zone_map_view(view, zones, most)
    v = ArizonaMap::VIEWS.fetch(view)
    marks = ArizonaMap::COUNTIES.fetch(view).map { |name, d| tag.path(tag.title("#{name} County"), d: d, class: "county") }
    marks << tag.path(d: ArizonaMap::STATE.fetch(view), class: "state")
    if view == "state"
      west, north = ArizonaMap.point("state", ArizonaMap::VIEWS["metro"][:north], ArizonaMap::VIEWS["metro"][:west])
      east, south = ArizonaMap.point("state", ArizonaMap::VIEWS["metro"][:south], ArizonaMap::VIEWS["metro"][:east])
      in_metro = zones.slice(*METRO_ZONES).values.compact.sum
      marks << tag.rect(x: west, y: north, width: (east - west).round(1), height: (south - north).round(1), class: "inset")
      marks << tag.text("Phoenix metro, #{in_metro}+ (right)", x: west, y: south + 14, class: "zone-label")
      TOWNS.each do |town, (lat, lon)|
        x, y = ArizonaMap.point("state", lat, lon)
        marks << tag.circle(cx: x, cy: y, r: 2.5, class: "town")
        marks << tag.text(town, x: x + 5, y: y + 4, class: "town-label")
      end
      marks += zone_dot("state", "Tucson and the south", zones, most)
    else
      METRO_COUNTIES.each do |county, (lat, lon)|
        x, y = ArizonaMap.point("metro", lat, lon)
        marks << tag.text(county, x: x, y: y, class: "county-label")
      end
      METRO_ZONES.each { |name| marks += zone_dot("metro", name, zones, most) }
    end
    tag.svg(safe_join(marks), class: "az-#{view}", viewBox: "0 0 #{v[:width]} #{v[:height]}")
  end

  def zone_dot(view, name, zones, most)
    return [] unless zones.key?(name)
    n = zones[name]
    return [] if n&.zero?
    lat, lon, side = ZONE_PLACES.fetch(name)
    x, y = ArizonaMap.point(view, lat, lon)
    r = n ? [Math.sqrt(n / most) * MAX_RADIUS, MIN_RADIUS].max.round(1) : MIN_RADIUS
    text = "#{name}#{" (the lab)" if name == LAB_ZONE}: #{n || "fewer than 5"}"
    slot = ZONE_PLACES.keys.first(8).index(name)
    lx, ly, anchor = { left: [x - r - 5, y + 4, "end"], right: [x + r + 5, y + 4, "start"],
                       above: [x, y - r - 6, "middle"], below: [x, y + r + 13, "middle"] }.fetch(side)
    [tag.circle(tag.title(text), cx: x, cy: y, r: r, class: ["zone", ("few" if n.nil?)], style: ("--zone: var(--z#{slot + 1})" if slot && n)),
     tag.text(n || "<5", x: x, y: (y + 4).round(1), "text-anchor": "middle", class: ["zone-num", ("few" if n.nil?)]),
     tag.text(name == LAB_ZONE ? "#{name} (the lab)" : name, class: "zone-label", x: lx.round(1), y: ly.round(1), "text-anchor": anchor)]
  end
end
