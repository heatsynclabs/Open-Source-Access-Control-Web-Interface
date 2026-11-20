# The laser settings page

`/laser` (menu: **Laser**, any signed-in member) is a settings guide for the large 80 W
laser, built from the jobs members log on the form by the machine. It is the members-site
version of the "80W Laser Log Explorer" a member built from the same log: the same
cleaning rules and the same numbers, in the site's own design, with no names.

| View | What it shows |
|---|---|
| Find a setting | Pick a material, a job (cut through or engrave) and a thickness: the typical power, speed and passes (or scan gap) from jobs that worked, how reliable that is, the spread, one vote per person, every setting tried (a power against speed chart) and the notes from jobs that struggled |
| All settings | One row per material and thickness with 3 or more jobs |
| What goes wrong | Trouble rates (MDF, thick plywood, multiple passes, a dirty start), the top complaints from the notes, and how the 3 mm plywood setting drifted by half year |
| Laser math | The energy per mm a cut takes (E = 0.8 x power / speed x passes), how it grows with thickness, an estimator for unlogged stock, whether lens cleans show up, whether laser hours wear the beam, and what the log cannot tell you |
| Cheat sheet | The settings on one printable sheet; pick a paper size and print (only the sheet prints) |
| The log | Every job, newest first, searchable by project and notes and filterable by material and result; names are not shown. "How the log was cleaned" lists every repair |

Usage of the laser (jobs, people and hours a month, results and materials by year) is on
the analytics page, Over the years, The laser cutter.

## Where the data comes from

The Google Sheet "Large 80W Laser Log (Responses)" (owned by admin@heatsynclabs.org)
collects the form's answers. Its form responses tab is shared as "anyone with the link can
view", so the site reads it as CSV with no login:

    https://docs.google.com/spreadsheets/d/1BpAYtyFIKQ4UoXv31mKC43YFxfBk34d_q-muw1SP2aU/export?format=csv&gid=1050947612

(`LaserLog::CSV_URL`; set `LASER_LOG_CSV_URL` to read another copy). If the sheet stops
being shared that way, the nightly read fails and the page keeps the last copy.

**Nightly.** `bundle exec rails laser:sync` reads the whole sheet, cleans every row and
replaces the table `laser_jobs` in one transaction. It refuses a sheet that does not start
with the form's columns, or that has under 90% of the jobs already held, and then keeps the
old rows. It also works out the Laser math once (about two seconds) so pages stay fast.
On production it runs in the same Coolify scheduled task as the guestlist check
([Operations](operations.md)). By hand: run the command in `members_web` from `/app`.

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
- three rows have hand corrections, keyed by their timestamp (`Cleaner::OVERRIDE`).

The rules are a Ruby port of the explorer's `process_laser_log.py`; on the log of
2026-11-19 they give the same result for every field of all 1,424 jobs.

**Names.** The name on the form is read only while cleaning (one material rule uses it) and
to tell people apart: `person_key` is a keyed hash of a short form of the name (the app's
secret is the key), so jobs by the same person group together for "one vote per person"
and people counts without anyone being named. Project titles and notes are kept and shown,
since they are what makes the log useful; nothing on the page shows who logged a job.

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
  explorer's job classifier (scikit-learn) is not ported. Optics work comes from the
  machine notes and is listed in `Laser::Model::OPTICS`: add a line when the lens is cleaned
  or the beam realigned.

## Code

`app/models/laser_log.rb` (sheet address, person key), `laser_log/cleaner.rb`,
`laser_log/sync.rb`, `laser_job.rb`; `app/queries/laser/` (`log`, `stats`, `settings`,
`trouble`, `model`, `usage`); `app/controllers/laser_controller.rb`;
`app/views/laser/`; `app/helpers/laser_helper.rb` (the two drawn charts);
`app/javascript/controllers/laser_estimate_controller.js`, `print_controller.js`;
`app/assets/stylesheets/pages/laser.scss`; `lib/tasks/laser.rake`. Tests:
`test/models/laser_log_test.rb`, `test/queries/laser/`, `test/integration/laser_test.rb`.
