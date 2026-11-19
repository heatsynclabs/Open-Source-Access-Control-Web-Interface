# Files and waivers

The site stores two kinds of files:

- **Signed waivers** (the scanned or photographed liability waiver on each contract). They
  hold members' personal details and signatures.
- **Tool photos** on the tools and resources pages.

## Where they are

Both live in **members-files**, the lab's own file store: Garage, an S3-compatible server,
running on the lab's server in Coolify, with its data under `/data/members-files`. It has
two buckets:

| Bucket | Holds | Who can read it |
|---|---|---|
| `members-waivers` | signed waivers (`documents/<id>/...`) | only the production site (and the nightly backup) |
| `members-photos` | tool photos (`pictures/`, `picture2s/`, ...) | the production site, the backup, and staging (read only) |

The file store has no public address. Nobody reaches a file directly: every file goes
through the site, which checks who is asking first.

Until 2026-11-18 the files were in an Amazon S3 bucket (`Toolshare`). They were copied to
the lab's store and checked file by file. The Amazon copy is kept, read-only, while the
Board decides when to close it.

## Who can see what

| File | Address on the site | Who |
|---|---|---|
| A signed waiver | `/contracts/<id>/document` (on the contract's page) | admins only. Never cached by the browser or Cloudflare |
| A tool photo | `/resources/<id>/photo/<picture>/<size>` | anyone, like the tools pages. Cached for a day |

Only known-safe file types are shown in the browser (PDF, JPEG, PNG, GIF, WebP); anything
else downloads. Waivers are served with headers that stop the browser running anything in
them.

## Uploading

- **Waivers:** PDF, JPEG or PNG, up to 20 MB. Scans (images) get small previews; PDFs are
  kept exactly as uploaded. When a contract record is deleted, its waiver file is kept in the
  store on purpose: deleting signed waivers is a decision for the Board.
- **Tool photos:** JPEG, PNG, GIF or WebP, up to 15 MB each, four per tool, with preview
  sizes made automatically.

The file type is checked from the file's contents, not just its name (Paperclip with the
`file` tool).

## Backups

Every night at 01:30 a small helper in the members-files service copies both buckets into
`/data/backups/offsite/members-files/` on the server. The off-site backup (SpiderOak)
uploads that folder, encrypted, twice a day. When a file changes or is deleted, its
previous version is kept in `/data/backups/offsite/members-files-history/<date>/`. The log
of each run is `/data/backups/offsite/members-files/BACKUP-LOG.txt`.

## Settings

The site reads these from its environment (Coolify). With no `S3_ENDPOINT` it would use
Amazon S3.

| Setting | Production | Meaning |
|---|---|---|
| `S3_ENDPOINT` | `http://members-files:3900` | the lab's file store, on the server's private network `files-net` |
| `S3_REGION` | `garage` | the store's region name |
| `S3_BUCKET` | `members-photos` | tool photos |
| `S3_DOCUMENTS_BUCKET` | `members-waivers` | signed waivers |
| `S3_KEY`, `S3_SECRET` | (secret) | the site's key: read and write on both buckets |

Staging uses a different key that can read the photos only. It cannot see any waiver, and
cannot upload or delete anything.

## If files do not show

- **The photo or waiver is missing or broken.** In Coolify, check the `members-files` service
  is running, and check the members site's logs for "stored file ... not read".
- **An upload fails.**
  - The file type or size may not be allowed (the form says why).
  - Otherwise the site's key may have changed: compare `S3_KEY` with the store's keys (IT
    officers, operations folder).

The operations folder has the full runbook (`reference/files-cutover-runbook.md`),
including how the store was set up and how to restore from the backup.
