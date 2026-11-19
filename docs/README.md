# Members site documentation

Plain-language guides to how HeatSync Labs' members site works, how to look after it,
and how to change it. Start with the overview.

| Guide | For | What it covers |
|---|---|---|
| [Overview](overview.md) | everyone | what the site does, the parts it is made of, and how they connect |
| [Door access](door-access.md) | admins, maintainers | remote door control, the door board, door-api, the night lock, the door log |
| [Access cards](cards.md) | admins | adding, disabling, deleting and uploading cards, and what "slot" means |
| [Files and waivers](files-and-waivers.md) | admins, maintainers | where waivers and tool photos are stored, who can see them, backups |
| [Environments and deploying](environments-and-deploying.md) | maintainers | production and staging, how a change gets from a branch to the live site, undoing one |
| [Configuration](configuration.md) | maintainers | every setting, what it does, where it is set |
| [Development](development.md) | maintainers | running the site on a laptop, the tests, the door emulator |
| [Operations](operations.md) | whoever is on call | scheduled jobs, health checks, logs, backups, what to do when something breaks |

Passwords, keys and other secrets are never in this repository. They are kept by the
lab's IT officers (the operations folder's `secrets/SECRETS.md`) and in Coolify's
settings for each app.
