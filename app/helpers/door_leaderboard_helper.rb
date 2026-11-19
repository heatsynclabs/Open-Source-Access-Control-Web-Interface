module DoorLeaderboardHelper
  # "4.5 h", or "4 h" and "0 h" for whole hours.
  def door_hours(hours)
    "#{number_with_precision(hours, precision: 1, strip_insignificant_zeros: true)} h"
  end

  # "2 full shifts, opened 5, locked up 3", leaving out the zeros.
  def door_leaderboard_detail(row)
    [
      (pluralize(row.shifts, "full shift") if row.shifts.positive?),
      ("opened #{row.opened}" if row.opened.positive?),
      ("locked up #{row.locked}" if row.locked.positive?),
    ].compact.join(", ")
  end

  # The months of door log nobody has: from where the recovered archive
  # ends to where the live log begins ("October 2020 to July 2022").
  def door_lost_span
    archived = DoorActivityArchive.span
    "#{archived ? archived.last.strftime('%B %Y') : 'April 2020'} to July 2022"
  end
end
