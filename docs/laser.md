# The laser settings page

`/laser` (menu: **Laser**, any signed-in member) is a settings guide for the lab's two
laser cutters, the Large 80W (the default) and the Mini 60W (`?machine=mini`), built from
the jobs members log on the form by each machine. A switch at the top picks the machine;
every view is that machine's alone. Above every view of the Mini sits its **tube reading**:
how strong it cuts by the log, against the Large (below, The numbers). For the large laser it is the members-site version of
the "80W Laser Log Explorer" a member built from the same log: the same cleaning rules and
the same numbers, in the site's own design, with no names.

| View | What it shows |
|---|---|
| Find a setting | Pick a material, a job (cut through or engrave) and a thickness: the typical power, speed and passes (or scan gap) from jobs that worked, how reliable that is, the spread, one vote per person, every setting tried (a power against speed chart) and the notes from jobs that struggled |
| All settings | One row per material and thickness with 3 or more jobs |
| What goes wrong | Trouble rates (MDF, thick plywood, multiple passes, a dirty start), the top complaints from the notes, and how the 3 mm plywood setting drifted by half year, with optics work as dashed lines |
| Laser math | On the Mini, the tube reading in full first. Then the energy per mm a cut takes (E = watts / 100 x power / speed x passes: 0.8 on the large laser, 0.6 on the mini), how it grows with thickness, an estimator for unlogged stock, whether lens cleans show up, whether laser hours wear the beam, and what the log cannot tell you |
| Cheat sheet | The laser explorer's 11 x 17 in wall sheet, ported as drawn (logo plate, hazard tape, key, family tables with the big power and speed figures, three cards, footer, in its own print colours; `_sheet.html.erb`, `.sheet` in `pages/laser.scss`). It zooms to fit the screen; pick a paper size and print (only the sheet prints): the whole sheet scaled to one page of any size (Letter at about 64%), so nothing spills onto a second page. If the logged materials outgrow one sheet, `sheet_fit_controller.js` switches it to a denser layout |
| The log | Every job from the machine's current and old forms, newest first, searchable by project and notes and filterable by form, material and result; names are not shown. "How the log was cleaned" lists every repair |

Usage of both lasers (jobs and hours a month per machine, people, results and materials by
year) is on the analytics page, Over the years, The laser cutters.

## Where the data comes from

Each laser has a Google Form by the machine, and each form replaced an older one in April
2022. People still log on an old form now and then, so the site reads all four response
sheets (`LaserLog::SHEETS`; the wiki's Large 80W Laser and Mini 60W Laser pages link them).
They are shared as "anyone with the link can view", so the site reads them as CSV with no
login:

| Machine | Form | Sheet | Jobs (2026-11-20) |
|---|---|---|---|
| Large 80W | current, from 2022-04-29 | `1BpAYtyFIKQ4UoXv31mKC43YFxfBk34d_q-muw1SP2aU`, tab `1050947612` | 1,424 |
| Large 80W | old, 2013-10-29 to 2022-04 | `0AoBMPvlNCqvldHl5SERwRHVjN09wRHEtODZzd2RXNWc` | 2,619 |
| Mini 60W | current, from 2022-04-29 | `1tDxqWNbrJ9M5UuvxpV4khA5Drt6HOfNuQRQbdNvYTxM` | 1,239 |
| Mini 60W (2011 to 2013: the Large's) | old, 2011-08 to 2013-05, then 2019-11 to 2022-04 | `1gItwjL4vfXwAsAQZ4dHuAlmoJ7lkLDme82yCei9KeF8`, tab `1432871391` | 1,424 |

The sheets have no machine column: each job counts for the machine its form is for, with
one exception. The mini's old form was first the large laser's: the large laser is the
lab's 2011 Exlas (its manual and import papers are in the Board's records; it came with a
100 W tube and runs an 80 W one now), and the mini came around 2019 (Slack, October 2019).
The form's 1,139 jobs from 2011 to 2013 are stored as machine `first` (`LaserJob::FIRST`,
`LaserLog::FIRST_LASER_UNTIL`) so that each sheet's nightly replace touches only its own
rows. The analytics page counts them as the Large's (`LaserJob.stored`); the Laser page
leaves them out, since its settings are for the tubes the lasers have now, and its mini
starts in November 2019. If a sheet stops being shared, its nightly
read fails and the site keeps its last copy.

**The old forms** (`LaserLog::Layout`) are read by header name into the current form's
column order, then cleaned by the same `LaserLog::Cleaner`:

- neither asked "Did you use cutting / engraving?": a job cut or engraved when it has that
  power and speed;
- the large laser's old form took materials as free text (192 spellings), put in the form's
  terms by `Layout::OLD_MATERIALS` (first match wins); the text as logged is kept and shown
  in the log ("logged as masonite"). Its thickness is a number of mm. It never asked for
  results, so they are "not recorded";
- the mini's old form already used the form's materials and results, with a few older
  spellings (`Layout::OLD_MINI_NAMES`).

The old forms show as history beside the current one: in the log, in "Find a setting" and
"All settings" (what people used then, and for the mini how many of those worked), and in
the 3 mm plywood drift (hollow points). The typical setting that worked, how reliable it is,
the cheat sheet, trouble rates and the laser math come from the current form only.

**Nightly.** `bundle exec rails laser:sync` reads each sheet, cleans every row and replaces
that sheet's jobs in `laser_jobs` (columns `machine` and `source`) in one transaction. It
refuses a sheet that does not start with a Timestamp column, or that has under 90% of the
jobs already held from it, and keeps that sheet's old rows; the others still update, and
the task ends with an error so the failure shows in Coolify. It also works out each
machine's Laser math once (a few seconds) so pages stay fast. On production it runs in the
same Coolify scheduled task as the guestlist check ([Operations](operations.md)). By hand:
run the command in `members_web` from `/app`.

## Cleaning (LaserLog::Cleaner)

The form accepts anything, so each row is repaired and every repair is recorded
(`laser_jobs.fixes`, shown under The log):

- materials logged under different names fold together (Wood and Plywood; OTHER with a note
  that says what it was; thin polystyrene is sheet, thick is foam);
- thickness text becomes millimetres and a bucket ("3 mm (1/8 in)");
- power and speed typed into each other's box are swapped back;
- on rigid stock, a fast (100 mm/s and up) or very low power vector pass is a score, not a cut;
- impossible pass counts (over 10) and scan gaps over 0.5 mm are dropped ("008" is read as
  0.08);
- glass settings typed in the cut boxes are read as engrave;
- free-text results become success, conditional (partly worked) or fail;
- notes on jobs that did not work are tagged by keyword (did not cut through, fire or
  burning, software, focus or alignment, smoke, warped material);
- three rows of the large laser's current form have hand corrections, and six rows logged as
  OTHER are cast stone, keyed by their timestamps (`Cleaner::OVERRIDE`, `Cleaner::CAST_STONE`;
  not applied to the other sheets).

The rules are a Ruby port of the explorer's `process_laser_log.py`; on the large laser's log
of 2026-11-19 they give the same result for every field of all 1,424 jobs. The same rules
clean the mini's and the old forms; their repair counts are under The log.

**Names.** The name on the form is read only to tell people apart: `person_key` is a keyed hash of a short form of the name (the app's
secret is the key), so jobs by the same person group together for "one vote per person"
and people counts without anyone being named. Jobs logged with no name (45, all on the
large laser's old form) get a blank key and count toward jobs, not people. Project titles and notes are kept and shown,
since they are what makes the log useful; nothing on the page shows who logged a job, and the page does not link the response sheets
(they hold names). A failing sheet (an error page, a dropped connection) is reported and keeps its rows; the others still update.

## The numbers

- **Typical setting**: the median power and speed of the jobs that worked (successes; if
  fewer than two, everything that was not a failure). Engrave uses raster (fast) jobs when
  there are any.
- **How it goes**: reliable (90% or more clean success), mostly works (75 to 89%), hit or
  miss (under 75%); "few jobs" under 5 good jobs, "varies a lot" when the middle half of
  speeds spans 3 times or more, or of powers 35 points or more.
- **Laser math** (`Laser::Model`, a port of the explorer's `model_laser.py`): least squares
  of log E on material and log thickness over clean cuts through rigid stock at 2 mm and
  up; intervals resample people, not jobs (600 and 400 draws, fixed seed). Its numbers equal
  the explorer's except the random intervals, which can differ by a few tenths. The
  explorer's job classifier (scikit-learn) is not ported. Each machine is fitted on its own
  log at its own wattage (`LaserJob::WATTS`). Optics work comes from the machine notes and
  is listed per machine in `Laser::Model::OPTICS`: add a line when a lens is cleaned or a
  beam realigned. None is noted for the mini, so its math has no optics sections.
- **Tube reading** (`Laser::Tube`, the Mini only): how strong the Mini cuts, in watts,
  against the Large. Take the clean cuts through rigid stock at 2 mm and up on both current
  forms. For each person who cut the same material and thickness on both lasers, the gap is
  log(power x passes / speed) on the Large minus the same on the Mini, as a median over
  their shared stock: one vote per person. The reading is the Large's rated watts times
  exp(the Hodges-Lehmann middle of the votes), which stays steady when many people copy one
  class setting; the range resamples people (400 draws, fixed seed). It needs 15 people
  (`Tube::PEOPLE`); stocks with 5 or more are listed, each read the same way. On 2026-11-20:
  52.8 W (49.9 to 55.0) from 131 people, so the Mini cuts like about 53 W against its rated
  60 W, and settings from the Large carry over at the same power and about two thirds of
  the speed. The rating (`LaserJob::WATTS`) stays as it is everywhere else, J/mm included.
  It is a comparison, not a power meter: it takes the Large at its rating, reads the whole
  beam (tube, mirrors, lens, power supply) and reads habit as well as power. When either
  laser gets a new tube, add the date to `Laser::Tube::REPLACED`: the reading starts over
  from that day, and the strip says how many people it still needs. It is worked out once
  per sync (about a second) and cached.

## Code

`app/models/laser_log.rb` (the sheets, person key), `laser_log/layout.rb`,
`laser_log/cleaner.rb`, `laser_log/sync.rb`, `laser_job.rb`; `app/queries/laser/` (`log`, `stats`, `settings`,
`trouble`, `model`, `tube`, `usage`); `app/controllers/laser_controller.rb`;
`app/views/laser/` (`_tube.html.erb` the strip, `_tube_card.html.erb` its Laser math card);
`app/helpers/laser_helper.rb` (the drawn charts and the tube gauge);
`app/javascript/controllers/laser_estimate_controller.js`, `print_controller.js`;
`app/assets/stylesheets/pages/laser.scss`; `lib/tasks/laser.rake`. Tests:
`test/models/laser_log_test.rb`, `test/queries/laser/`, `test/integration/laser_test.rb`.
