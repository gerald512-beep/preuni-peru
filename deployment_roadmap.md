# PreUni Perú — Production Deployment Roadmap

**Last updated:** 2026-09-14
**Target platform:** Discourse on AWS Lightsail (São Paulo, sa-east-1)
**Instance:** `preuni-discourse-prod` — 2 vCPU / 8GB RAM / 160GB SSD — $44/mo
**Static IP:** `18.231.103.224`
**Current phase:** Server + Docker ready, domain DNS live (`preuni.voluntaria.pe`). Blocked on Amazon SES setup before Discourse itself can be launched.

Cloud provider decision (AWS Lightsail vs. GCP Compute Engine cost/tradeoff comparison) was made earlier — AWS chosen for lower cost at the target spec and better fit with Discourse's own install docs/community.

---

## Done

- [x] Cost/tradeoff comparison: AWS Lightsail vs. GCP Compute Engine (compute, storage, egress, region maturity) — chose AWS
- [x] IAM user `lightsail-preuni` created, scoped to `lightsail:*` only (no AWS-managed "full access" policy exists for Lightsail — used a custom policy)
- [x] AWS CLI installed locally and configured as profile `preuni`
- [x] Lightsail instance created: Ubuntu 24.04 LTS, São Paulo Zone A, General Purpose 2vCPU/8GB/160GB/2.5TB transfer
- [x] Static IP attached (`18.231.103.224`)
- [x] Firewall opened: SSH (22), HTTP (80), HTTPS (443) — any IPv4/IPv6
- [x] SSH access established from the local dev machine (see gotcha below)
- [x] Docker CE + Compose plugin installed via Docker's official apt repo
- [x] Official `discourse/discourse_docker` launcher cloned to `/var/discourse` on the server

## Remaining — in order

1. [x] **Domain** — `preuni.voluntaria.pe` chosen. DNS is managed via Cloudflare (not GoDaddy, despite GoDaddy being the registrar). Added an A record (`preuni` → `18.231.103.224`, DNS-only/grey-cloud, not proxied) — confirmed resolving 2026-09-14.
2. [x] **Amazon SES** — domain identity `preuni.voluntaria.pe` verified (DKIM: SUCCESS). Production access requested via `put-account-details` — pending AWS's async review (~24h typical; doesn't block anything below, sandbox only restricts recipient addresses until approved). SMTP credentials generated (dedicated IAM user `ses-smtp-preuni`, scoped to `ses:SendRawEmail` only) and saved to `.env` as `SES_SMTP_HOST`/`PORT`/`USERNAME`/`PASSWORD`. Completed 2026-09-14.
3. [x] **Write production `app.yml`** — real `DISCOURSE_HOSTNAME` (`preuni.voluntaria.pe`), SES SMTP settings pulled from `.env`, `DISCOURSE_SKIP_EMAIL_SETUP` removed. Completed 2026-09-15.
4. [x] Ran `./launcher bootstrap app` then `./launcher start app` — container up and serving.
5. [x] HTTPS / Let's Encrypt confirmed — valid cert for `preuni.voluntaria.pe`, issued 2026-09-15, expires 2026-12-14, auto-renews.
6. [ ] Re-run category/tag seeding against production (`seed-categories.sh`, `seed-tags.sh`, pointed at the new instance's API)
7. [ ] Install the `preuni-question-widget` plugin (`plugin.rb` + `.gjs`/`.js` files) on production, rebuild container
8. [ ] Re-create custom groups (`universitario`, `egresado`, `moderador`) and badges on production
9. [ ] Decide: migrate the 52 already-published UNI questions from local, or start production fresh
10. [ ] Set up Discourse's native backup-to-S3 (create bucket in `sa-east-1`, scoped IAM credentials, enable in admin settings)
11. [ ] End-to-end smoke test: registration, OA gate, answer submission, difficulty badge, typed posts (Pregunta/Solución/Comentario)
12. [ ] Go live

## Guardrails — local (test) vs. AWS (production)

Agreed 2026-09-14: local Discourse (`localhost:8080`) is the test environment; AWS Lightsail is production. Claude is responsible for checking these before any action that touches production or promotes something from local to it.

- ~~Category IDs are not portable~~ **Fixed 2026-09-15**: `server.js` now looks up categories by name via `/site.json` (`getCategoryId`/`getCategoryIdsForUniversidad`) instead of the old hardcoded `CATEGORY_MAP`, which had already drifted stale locally (12 hardcoded UNI subjects vs. 23 actual). Composer tool now works correctly against any target just by pointing `DISCOURSE_URL` at it — no more manual ID sync needed.
- **`restart` does not apply config or plugin changes — `rebuild` does.** Any `app.yml` edit or plugin change requires `./launcher rebuild app`. Don't conclude a change "didn't work" without checking which one was run.
- **Promotion is one-directional: local → production, never sideways.** Plugin code, taxonomy, and composer changes are authored and tested locally first, then deliberately pushed to production (git push → pull on server → rebuild). Never hand-edit plugin files directly over SSH on the production box.
- **Pin cloned plugin versions once stable.** `app.yml`'s `hooks` do a bare `git clone` (docker_manager now; the custom widget and any third-party plugins later) — this pulls whatever is on `main` at rebuild time. Local and production rebuilding on different days can silently end up on different plugin versions.
- **Keep local vs. production credentials/targets separate and visible.** One `.env` currently holds both. Before running the composer tool, confirm which `DISCOURSE_URL` is active — don't let test content reach production or vice versa by accident.
- **Backup before anything structural on production**: before a rebuild that changes plugins, before any bulk question import, before restructuring categories/groups.
- **Every new credential (S3, future integrations) gets scoped narrowly**, same as the Lightsail/SES IAM users — and rotated immediately if ever accidentally exposed on screen.

## Gotchas hit along the way (for future reference)

- AWS Lightsail's São Paulo region does **not** require opt-in enabling — it's one of AWS's original regions (since 2011), unlike some other recently-added Lightsail regions.
- There is no AWS-managed "full Lightsail access" policy to attach — had to write a custom policy (`{"Effect":"Allow","Action":"lightsail:*","Resource":"*"}`).
- An access key was briefly exposed in a screenshot and was rotated immediately as a precaution.
- The Lightsail-generated "default" SSH key did not authenticate against the instance for unknown reasons; worked around by appending a second, dedicated key pair to `~/.ssh/authorized_keys` via the browser-based SSH terminal.
- `./launcher start`/`restart`/`rebuild` all echo the full `docker run` command to their own output **including secrets in plaintext** (e.g. `DISCOURSE_SMTP_PASSWORD=...`). Always pipe through a redaction filter (e.g. `sed -E 's/(DISCOURSE_SMTP_PASSWORD=)[^ ]+/\1[REDACTED]/g'`) before this output reaches anywhere it could be logged or displayed. One SMTP credential was exposed this way and had to be rotated.
- `./launcher restart app` does **not** apply `app.yml` changes — it just stops/starts the *existing* container with whatever env vars were baked in at its last `docker run`. To apply a config change without a full image rebuild, use `./launcher destroy app && ./launcher start app` (recreates the container from current `app.yml` using the already-built image). A full `./launcher rebuild app` is only needed when `hooks`/templates change (e.g. adding a template), not for plain env var edits.
- `templates/web.letsencrypt.ssl.template.yml` alone is **not sufficient** for HTTPS — it only patches a marker file (`/etc/runit/1.d/install-ssl`) that `templates/web.ssl.template.yml` creates. Omitting the base SSL template makes the Let's Encrypt hook silently no-op (no error, cert just never gets issued). Both templates are required, in that order.
