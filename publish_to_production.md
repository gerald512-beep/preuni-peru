# Publish a reviewed batch to PRODUCTION (preuni.voluntaria.pe)

**How to use (paste into a new Claude Code session at `C:\Dev\GmatClubScrap`):**

> Read publish_to_production.md and run it for BATCH=uni_2025_2

`BATCH` is the id of a file in `bulk_data/` (without `.json`) that has already been reviewed with `review_batch_prompt.md` **and published to local Discourse**. That review is NOT repeated here. This runbook covers everything from "the batch is good on local" to "the batch is live and verified on production".

Written for: the Claude Code session that will run it (the user supervises and approves the gates).

---

## 0. Hard rules (read first, follow throughout)

1. **Three approval gates.** Stop and wait for an explicit "go" from the user at each one. A gate is not passed by silence, by a previous approval, or by this document.
   - **G1** after the read-only pre-flight, before ANY change on production (backup, site setting, API key).
   - **G2** before the pilot (publishing exactly one question).
   - **G3** before the full run.
2. **Production** = `https://preuni.voluntaria.pe`, host `ubuntu@18.231.103.224`, key `~/.ssh/preuni_prod`, container `app`, plugin dir `/var/www/discourse/plugins/preuni-question-widget`. SSH form: `ssh -i ~/.ssh/preuni_prod ubuntu@18.231.103.224 "<commands>"`. Use as few SSH connections as possible: one `scp` with all files, then one `ssh` with all commands. If SSH fails with "Connection reset by peer", test `ssh -T git@github.com`; if that also fails, the user's network blocks port 22 (ask them to change network). The server is not the problem.
3. **Rails on production:** `sudo docker exec -u discourse -w /var/www/discourse app bundle exec rails runner /tmp/<script>.rb` (copy scripts in with `scp` to `~/`, then `sudo docker cp ~/<script> app:/tmp/<script>`). Quick read-only SQL: `sudo docker exec app sudo -u postgres psql -d discourse -c "..."`.
4. **Never** rebuild/restart the production container, deploy plugin code, edit files on the production box, or change any site setting other than the one approved at G1. Do not commit or push.
5. **The API key is a secret.** Never print it, never `cat` the key file, never put it in `.env`, a repo file, a command line literal, or a log. It lives only in a scratchpad file and is revoked + deleted in Phase F, **even if the run fails midway**.
6. **Do not pollute production metrics.** Loading a production question page in a browser while not logged in records a `pregunta_vista` event (MVP metrics), one anonymous topic view (`topic_views`, `topics.views`, `topic_view_stats`) and a `browser_pageview_events` row. Use only `check_render.js` and `shot_topic.js` for browser checks: they block the metrics beacon (0 `preuni_eventos`, verified), but **the page load itself still counts the topic view and the pageview event**. `cleanup_views.rb` removes those in F2 — always run it. Do NOT open production pages with the Playwright MCP browser or any other browser: its persistent profile has Discourse's service worker registered, so route blocking can miss the beacon (2026-10-04: 4 `pregunta_vista` events on topic 338 came from such tests). JSON/API reads with `curl`/`fetch` count nothing and are fine.
7. **Write scripts with the Write tool**, never with bash heredocs: Git Bash mangles backslashes (LaTeX `\frac`, regex `\d`) inside heredocs. Put them in your scratchpad, e.g. `$SCRATCH/prodpub/` (define `SCRATCH` as your session scratchpad path).
8. **Stop on any failed check**, report what you saw, and ask. Do not improvise fixes on production data. The one data fix this runbook allows on its own is the documented math-delimiter fix in A4, which applies to the local batch file only.
9. Edit batch JSON only through script files, and keep `bulk_data/<BATCH>.json` (source, local topic ids) and `bulk_data/<BATCH>_PRODUCTION.json` (production copy) consistent for any content fix.

---

## 1. Inputs and the definition of done

| Item | Value |
|---|---|
| Source batch | `bulk_data/<BATCH>.json` (reviewed, every record `published: true` with a LOCAL `topicId`) |
| Production copy | `bulk_data/<BATCH>_PRODUCTION.json` (created in A5; precedent: `uni_2019_2_PRODUCTION.json`) |
| Publisher | `publish_to_discourse.js <batchId>` (repo root). Headless copy of the preview's "Publicar pendientes": talks to `http://localhost:3000`, skips records that are `published`, `hold`, or have `needsReview`, waits 1.5 s between records, and stamps `published/topicId/topicUrl/publishedAt` into the batch file after each success. The stamp is retried 4 times; a topic that was created but could not be stamped prints `STAMP-FAIL` plus the exact restamp command, and the run ends with `VERIFY stamped x/y` and `DONE ... stamp_failed=N` (exit code 1 if anything failed). On 2026-10-04, before that fix, 3 of 178 stamps were lost silently. |
| Composer server | `server.js` on port 3000. It reads `DISCOURSE_URL`, `DISCOURSE_API_KEY`, `DISCOURSE_API_USERNAME` at start-up (dotenv does NOT override variables that are already set in the environment) and caches the category map per process. **A restart is required to change targets.** |

**Expected numbers:** recompute in A2 for every batch. For reference, `uni_2024_2` (published to production 2026-10-04, topics 348..527) had 180 records (P1 100, P2 40, P3 40), universidad UNI, anio 2024, convocatoria II, modalidad Ordinario, 20 temas, 180 solutions, 23 stem figures + 32 choice images + 53 solution figures, at most 5 tags on one record, 0 clusters, 0 `needsReview`, 0 `hold`; local topics 568..747.

**State after the 2024-II run (2026-10-04):** production has 485 questions (index rows 485); `max_tag_length` is 50 on BOTH production and local, so tags up to 50 characters are no longer truncated.

**Done means:**
- all N records are published on production;
- the publisher printed `stamp_failed=0` and `<BATCH>_PRODUCTION.json` has N records stamped with production URLs;
- `validate_publish.rb` reports 0 problems and 0 truncated tags;
- `check_render.js` and `shot_topic.js` report no problems and `find_blank.py` reports 0 blank screenshots;
- search shows N for that universidad/año;
- metrics are untouched, and `cleanup_views.rb` has removed this run's topic views and pageview events;
- the API key is revoked and deleted, and the composer server is back on local;
- the report is delivered and memory is updated.

---

## 2. Scripts (write each to `$SCRATCH/prodpub/` with the Write tool)

All scripts are listed in the Appendix, exactly as used in the 2024-II production run (2026-10-04):

| Script | Runs where | Purpose |
|---|---|---|
| `make_expected.js` | local (node) | From a batch file, builds `expected.json`: one row per **published** record with topicId, fields, tags, image and formula counts. |
| `preflight.rb` | Discourse (rails runner) | Read-only. Settings, categories, tags that are missing or would be truncated, "already published?", baseline counters, latest backups. |
| `validate_publish.rb` | Discourse (rails runner) | Read-only. Every topic vs its record: category, custom fields, tags (and truncation), title hygiene, choices, images, math spans, solution reply + `preuni_post_type`, search-index row, duplicates. |
| `check_math_boundaries.js` | local (node) | Finds inline `$…$` that discourse-math will NOT render (letter/digit glued to a `$`). The preview's MathJax hides this problem. |
| `check_render.js` | local (node + headless Chromium) | Anonymous, read-only, beacon blocked. All images return 200; every formula (stems AND solutions) compiled by the site's own MathJax 4.1 — errors AND undefined commands (red text, no error; added 2026-10-04). Run it WITHOUT `--shots`: its screenshots come out blank for posts taller than its 900 px viewport. |
| `shot_topic.js` | local (node + headless Chromium) | Screenshot of each topic's question post (3000 px viewport, waits until images are decoded and every `.math` is typeset) plus a per-page check: MathJax errors, broken images, raw `$`. |
| `find_blank.py` | local (python + Pillow) | Lists screenshots that are empty below the header (file size can't tell a blank capture from a short post). Must report `blank 0`. |
| `pick_pilot.js` | local (node) | Ranks unpublished records by how many paths they exercise (stem figure, choice images, solution figure, math in the question, math in the solution, display math). |
| `cleanup_views.rb` | Discourse (rails runner) | Dry run, then apply: removes the anonymous topic views and pageview events that this run's own page loads created. |

`check_render.js` and `shot_topic.js` hard-code two local paths:
- `playwright-core` from the npx cache: `C:/Users/smart/AppData/Local/npm-cache/_npx/9833c18b2d85bc59/node_modules/playwright-core`;
- headless Chromium: `C:/Users/smart/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe`.

Verify both exist (`ls`). If one doesn't, find the replacement with:
- `find "$LOCALAPPDATA/npm-cache/_npx" -maxdepth 3 -name playwright-core`
- `ls "$LOCALAPPDATA/ms-playwright"`

---

## 3. Phase A — pre-flight (local + READ-ONLY production)

**A1. Local tools.**
- `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/bulk-preview.html` returns 200. If not, start the composer: PowerShell `Start-Process -FilePath "C:\Program Files\nodejs\node.exe" -ArgumentList "server.js" -WorkingDirectory "C:\Dev\GmatClubScrap" -WindowStyle Hidden`.
- **If it fails with `listen EACCES ... 0.0.0.0:3000`:** Windows (WinNAT) reserved a port range after WSL started; check with `netsh interface ipv4 show excludedportrange protocol=tcp` (2026-10-05: 2772–3438 reserved). Don't change system settings — pick a free port (4000 worked) and use it everywhere this runbook says 3000: start the server with `PORT=4000` (PowerShell: `$env:PORT='4000'` before `Start-Process`; Bash: `PORT=4000 node server.js`), run the publisher with `COMPOSER_URL=http://localhost:4000`, and use `http://localhost:4000/...` for `topic-info` and the bulk preview. Getting 3000 back needs a reboot or an admin `net stop winnat` + `net start winnat`; tell the user.
- `server.js` contains the current title rules. All three of these must be present:
  - `grep -cF "(?:left|right)(?![a-zA-Z])" server.js` returns 1 (`-F` is required: without it grep reads `[a-zA-Z]` as a bracket expression and returns 0 on a good file);
  - `grep -c "equiv: '≡'" server.js` returns 1;
  - `grep -c "parallel: '∥'" server.js` returns 1 (added 2026-10-04 with ε, φ, ⊥ and `\dfrac`/spaced `\frac`);
  - `grep -c "begin\\\\{\[a-zA-Z\*\]+" server.js` returns ≥ 1, or simply read `latexToPlain()`.

  If they're missing, STOP: the working tree is older than expected.
- `grep -n "^DISCOURSE_URL" .env` shows `http://localhost:8080`. Print only that line, never the key lines. This proves the default target is local, and `.env` is never edited in this runbook.

**A2. Source batch integrity.** With a node one-off (script file), check `bulk_data/<BATCH>.json`:
- record count, plus per-`prueba` and per-`tema` counts;
- every record has `published: true` and a numeric `topicId`, i.e. it was published locally;
- `needsReview` is empty for all, there is no `hold`, and `clave` is in A–E for all;
- `universidad`/`anio`/`convocatoria`/`modalidad`/`tipo_area` are as expected;
- `subtemas` is non-empty;
- the clusters count (clusters need linked publishing; uni_2024_2 has none).

Compare with the expected numbers in section 1. Any surprise: STOP.

**A3. Local publish sanity (proves the scripts work, and shows the known issues).**
1. `node $SCRATCH/prodpub/make_expected.js bulk_data/<BATCH>.json $SCRATCH/prodpub/expected_local.json`
2. Run `validate_publish.rb` on LOCAL Discourse:
   ```
   wsl -d Ubuntu -u root -- docker cp <wsl path of expected_local.json> app:/tmp/expected.json
   wsl -d Ubuntu -u root -- docker cp <wsl path of validate_publish.rb> app:/tmp/validate_publish.rb
   wsl -d Ubuntu -u root -- docker exec -u discourse -w /var/www/discourse app bundle exec rails runner /tmp/validate_publish.rb
   ```
   Use the PowerShell tool for `docker cp` with `/mnt/c/...` paths; Git Bash rewrites them. If local Discourse is down (502, "fetch failed"), start the WSL keep-alive first as a backgrounded call: `wsl -d Ubuntu -- bash -c "while true; do sleep 3600; done"`.
3. **Expected:** 0 problems, 0 truncated tags (local `max_tag_length` is 50 since 2026-10-04). Any problem the A4 fix explains is fine — report it, don't fix local in this runbook. For reference, uni_2024_2 on local (2026-10-04, before the local tag-limit change) had 180/180 rows, 0 duplicates, 3 truncated tags (`aptitud-y-humanidade`, `interes-mezclas-y-al`, `razones-proporciones`) and 1 problem (`p3-QUÍMICA-36: solution math spans 4 != expected 6`, the A4 fix); both stay on local.

**A4. Math delimiters that Discourse won't render.**
`node $SCRATCH/prodpub/check_math_boundaries.js bulk_data/<BATCH>.json` must end with `offending inline math spans: 0`.

discourse-math only accepts inline `$…$` when the character before the opening `$` and the character after the closing `$` are whitespace, punctuation, or the line edge. `$75^{\circ}$C` breaks: the rest of the line pairs up wrongly and shows raw `$`.

- **uni_2024_2: already fixed on 2026-10-04, so expect 0.** The only 2 hits were in `p3-QUÍMICA-36` solutionBody: `$75^{\circ}$C` → `$75^{\circ}\mathrm{C}$` and `$25^{\circ}$C` → `$25^{\circ}\mathrm{C}$`. The local topic for P3#36 still shows the old, broken text unless it was revised; that only affects A3's known result.
- **uni_2025_2 (2 hits) and uni_2022_1 (7 hits) are not fixed yet.** Fix them before their production run.
- **General rule for other hits:**
  - Move a glued unit or word inside the math as `\mathrm{...}`.
  - For prefixes like `CO$_2$`, put the whole token in math (`$\mathrm{CO_2}$`).
  - A space is acceptable only when the printed exam has one.
  - If a hit looks like an OCR error (e.g. `$\tilde{a}$nos`), STOP and ask.
- Re-run the checker: it must report 0. Re-run `make_expected.js` afterwards, because the math counts changed.

**A5. Build the production copy.** With a script:
1. Read `bulk_data/<BATCH>.json` and deep-copy every record, deleting `published`, `topicId`, `topicUrl` and `publishedAt`. Remove `hold` if present.
2. Write `bulk_data/<BATCH>_PRODUCTION.json` (2-space indent, like the server writes). If the file already exists, STOP and ask: a previous production run may have happened.
3. Verify: same count and same ids in the same order; 0 records `published`; every other field deep-equals the source.

The new file appears in the bulk-preview batch picker; that is expected. **Nobody may press "Publicar pendientes" on it in the browser.** The CLI publisher is the only publisher in this runbook.

**A6. Production read-only checks (one scp + one ssh).**
1. Build the pre-flight input from the SOURCE batch (its records are published locally, so `make_expected` includes them): `node make_expected.js bulk_data/<BATCH>.json $SCRATCH/prodpub/expected_preflight.json`.
2. Plugin parity: the server-side plugin files on production must equal git HEAD, ignoring CRLF. Production files have CRLF line endings; that is expected and harmless.
   ```
   # local
   for f in $(git ls-files plugin.rb app db); do echo "$(git show HEAD:$f | tr -d '\r' | md5sum | cut -d' ' -f1)  $f"; done | sort -k2 > $SCRATCH/prodpub/plugin_local.md5
   ```
   In the same SSH session, run (inside the container's plugin dir): `for f in plugin.rb app/controllers/*.rb app/models/*.rb db/migrate/*.rb; do echo "$(tr -d '\r' < $f | md5sum | cut -d' ' -f1)  $f"; done | sort -k2`.

   `diff` the two lists. **Any difference → STOP** (production runs different plugin code; deploying it is a separate, user-approved task). Checked 2026-10-04: identical. Production clones the plugin from GitHub `master` at rebuild (`app.yml`), so a commit that was never deployed shows up here as a difference.
3. `scp` `expected_preflight.json` and `preflight.rb` to the host, then copy them into the container as `/tmp/expected.json` and `/tmp/preflight.rb`, and run the pre-flight. Also run `curl -s https://preuni.voluntaria.pe/srv/status` (expect `ok`) and `df -h /`.
4. **Expected pre-flight on production:**
   - `discourse_math_enabled=true`, `tagging_enabled=true`, `max_tags_per_topic=5`, max tags on one record ≤ 5. `max_tag_length=50` (raised from 20 on 2026-10-04).
   - The parent category exists; missing subcategories `[]`. A missing subcategory → STOP (the publisher looks categories up by name).
   - Missing tags: they are created at publish time. "would be TRUNCATED" must be `[]`; a tag longer than 50 characters → STOP and ask (B2).
   - Topics already on production for this universidad/año/convocatoria: **0** (anything else → STOP).
   - Baseline: `index_rows` (485 after the 2024-II run), `max_topic_id`, `max_evento_id`. **Write these down;** Phase E compares against them.
   - Latest backups: weekly (2024-II run: manual backup `preuni-peru-2026-10-04-202919-…`, 17 MB); disk was 12 % used.
5. **Why truncation matters:** a tag name that doesn't exist yet is cut to `max_tag_length` characters when attached (existing long tags attach fine). The subtema filter in search works through tags, so a truncated subtema tag makes those questions disappear from that filter. With the old limit of 20, local got `aptitud-y-humanidade`, `interes-mezclas-y-al…` and `razones-proporciones`.

**A7. Report the pre-flight to the user and ask for GATE G1.** Include:
- counts;
- the A4 fix;
- plugin parity;
- the missing and too-long tags;
- the "already on production" count;
- the baseline;
- the pilot(s) you propose for Phase C (C1);
- a list of exactly what Phase B will change on production:
  - a new backup;
  - only if a tag is longer than 50 characters: the B2 option you recommend;
  - creating a temporary admin API key.

Wait for "go".

---

## 4. Phase B — prepare production (only after G1)

**B1. Backup.**
- Run `sudo docker exec app discourse backup` (1–2 min).
- Verify a new `.tar.gz` with today's UTC date in `/var/discourse/shared/standalone/backups/default/` (listing it needs `sudo`), at least the size of the previous one.
- Record its file name for the report.
- Off-site (S3) backups are still NOT configured. Ask the user whether they also want a copy downloaded (`scp` to a folder they choose, outside the repo).

**B2. Tag length — only if A6 listed a tag longer than `max_tag_length` (50).** Normally skip this step: since 2026-10-04 both sites allow 50 characters and missing tags are created at publish time. If a longer tag appears, offer the user two options at G1: raise `SiteSetting.max_tag_length` (and pre-create the tag with `Tag.find_or_create_by!(name: "<tag>")`, printing `name` and `name.length` — it must match exactly), or shorten that subtema slug in the batch (it must then also exist in the composer's `SUB_TEMAS`). Apply only the option they approved.

**B3. Temporary API key (admin, all actions, revoked in F2).** Create it so the plaintext goes straight into a scratchpad file without ever reaching the screen:
```
ssh -i ~/.ssh/preuni_prod ubuntu@18.231.103.224 "sudo docker exec -u discourse -w /var/www/discourse app bundle exec rails runner \"a = User.find_by!(username: 'admin'); k = ApiKey.create!(user: a, created_by: a, description: 'TEMP bulk publish <BATCH> <YYYY-MM-DD>'); print 'ID:' + k.id.to_s + %(\n) + 'KEY:' + k.key\"" > "$SCRATCH/prodpub/prod_key.txt"
```
- Check the file **without displaying the key**: `grep -c '^KEY:[0-9a-f]\{64\}$' "$SCRATCH/prodpub/prod_key.txt"` must print `1`; `grep '^ID:' "$SCRATCH/prodpub/prod_key.txt"` shows the key id. Record the id.
- If the grep doesn't print 1, the output is malformed. Do not retry blindly: revoke any key with that description (F2), then ask the user.
- Tested on local 2026-10-04: `ApiKey.create!` yields a 64-hex key with no scopes, i.e. full access for that user.

**B4. Point the composer server at production, without touching `.env`.**
1. Stop the local composer server. PowerShell: `$c = Get-NetTCPConnection -LocalPort 3000 -State Listen | Select-Object -First 1; Stop-Process -Id $c.OwningProcess -Confirm:$false`.
2. Start the production-pointed one as a **backgrounded Bash call** (`run_in_background: true`):
   ```
   cd /c/Dev/GmatClubScrap && DISCOURSE_URL=https://preuni.voluntaria.pe DISCOURSE_API_USERNAME=admin DISCOURSE_API_KEY="$(sed -n 's/^KEY://p' "$SCRATCH/prodpub/prod_key.txt")" node server.js
   ```
   The key is expanded by the shell and never appears in the command text. dotenv keeps these values because they are already set.
3. **Prove the target is production:**
   - production title, public JSON: `curl -s -H "Accept: application/json" https://preuni.voluntaria.pe/t/306.json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).title))"`
   - through the server: `curl -s http://localhost:3000/api/topic-info/306`

   The two titles must be identical. `topic-info` uses `DISCOURSE_URL` plus the API key, so this proves both. If they differ or it errors: STOP, go to Phase F.

From now until F1, **everything served by localhost:3000 talks to production.** Don't use the composer or the preview's publish buttons.

---

## 5. Phase C — pilot: one or two questions (only after G2)

Ask for G2 with the pilot record(s) named.

**C1. Pick the pilot and hold the rest.** Run `node $SCRATCH/prodpub/pick_pilot.js bulk_data/<BATCH>_PRODUCTION.json`. The pilots together must cover a stem figure, image choices, a solution figure, **math in the question AND in the solution**, and display math. If no single record covers everything, use two pilots, published one after the other (C2–C3 for each). For uni_2024_2 the first pilot `p1-RAZONAMIENTO_MATEMÁTICO-10` turned out to have NO math (image choices only), so `p2-MATEMÁTICA-24` (stem figure, solution figure, 19 formulas incl. display math) was added as a second pilot. With a script, set `hold: true` on every record except the current pilot in `<BATCH>_PRODUCTION.json` (not in the source).

**C2. Publish it:** `node publish_to_discourse.js <BATCH>_PRODUCTION`. Expect:
- `pending=1`;
- `OK <pilot id> -> https://preuni.voluntaria.pe/t/<slug>/<id>`;
- no `WARN`, no `STAMP-FAIL`;
- `VERIFY stamped 1/1` and `DONE ... ok=1 failed=0 stamp_failed=0`.

**C3. Validate the pilot.**
- `make_expected.js` on `<BATCH>_PRODUCTION.json`: only the published pilot(s) are included.
- Run `validate_publish.rb` on production: 0 problems and no truncated-tag lines.
- `node check_render.js https://preuni.voluntaria.pe $SCRATCH/prodpub/expected_prod.json` must end with `no problems`, MathJax 4.1.0 and 0 errors (and a formula count > 0: if it is 0, the pilots don't cover math — see C1).
- `node shot_topic.js https://preuni.voluntaria.pe <ids.json> $SCRATCH/prodpub/shots_pilot` (ids.json = `[<pilot topic id>]`) ends with `no problems`; `python find_blank.py $SCRATCH/prodpub/shots_pilot` reports `blank 0`.
- Look at the screenshot (Read tool) next to the same record's 👁 popup. Read-only: render the popup headlessly from `http://localhost:3000/bulk-preview.html?batch=<BATCH>_PRODUCTION` (call `openRealPreview(<index>)` and screenshot `.rq-page`; the Playwright MCP browser may be held by another session). Expected: same stem, figures, choices, and the title the popup predicted.
- Metrics untouched: `select * from preuni_eventos where id > <baseline max_evento_id>` returns 0 rows, or only events from real users (non-null `user_id` of a non-staff user, or a `visitante_id` that isn't yours). For an anonymous event, look up `browser_pageview_events` for that topic and time: `HeadlessChrome` from this machine's IP is yours; a regular Chrome UA on topic 338 is most likely another session's MathJax test (`review_batch_prompt.md`). Report anything unclear.

**C4. Report the pilot and ask for GATE G3.**

---

## 6. Phase D — full run (only after G3)

**D1.** With a script, remove `hold` from every record in `<BATCH>_PRODUCTION.json`. Then start the publisher as a **backgrounded** call that writes a log:
```
cd /c/Dev/GmatClubScrap && node publish_to_discourse.js <BATCH>_PRODUCTION > "$SCRATCH/prodpub/publish_prod.log" 2>&1
```
- It prints `batch=... total=N pending=<N minus pilots>`, then per record `OK <id> -> <url>` or `FAIL <id>: <msg>` (plus `STAMP-FAIL` if a created topic could not be stamped), a `progress x/y` line, and finally `VERIFY stamped x/y` and `DONE batch=... ok=.. failed=.. stamp_failed=..`.
- Expect roughly 15–40 minutes for 180 records. Discourse rate limits (HTTP 429, "Espera N segundos") are retried automatically.
- Don't poll in a tight loop: check the log every few minutes (or use Monitor on the log). You'll be notified when it exits.

**D2. Handling problems:**
- **`STAMP-FAIL <id>` / `stamp_failed>0`:** the topic exists on production but the batch file doesn't know it. Do NOT republish. Run the restamp command the publisher printed for it, then confirm the record is `published: true` in `<BATCH>_PRODUCTION.json` (E1's validator then checks its content). On 2024-II this happened to 3 of 178 records before the publisher reported it.
- **`FAIL <id>`:** the record stays unpublished in the production copy. Before re-running, make sure no orphan topic exists for it: in rails, `TopicCustomField.where(name: 'preuni_numero', value: '<numero>')`, then keep topics whose `preuni_universidad/anio/convocatoria/tema` match.
  - If an orphan exists (created, but stamping failed), do NOT republish. Stamp it: `curl -s -X POST "http://localhost:3000/api/bulk-question/<urlencoded id>/publish?batch=<BATCH>_PRODUCTION" -H "Content-Type: application/json" -d '{"topicId":<id>,"topicUrl":"https://preuni.voluntaria.pe/t/<id>"}'`.
  - Otherwise just run the publisher again; it only takes unpublished records.
  - Repeated identical failures: STOP and report.
- **`WARN <id>: solution failed`:** the topic exists without its solution reply. Don't hand-craft a reply. Report it to the user. The recommended fix, with their OK, is to delete that brand-new topic (`PostDestroyer.new(Discourse.system_user, topic.first_post).destroy`), clear its `published/topicId/topicUrl/publishedAt` in the production copy, and run the publisher again.
- **Title rejected:** handled automatically (fallback `Tema — N`, or the duplicate suffix ` — N° x (UNI 2024-II)`). Not an error.

**D3.** The run is complete when the log says `DONE ... failed=0 stamp_failed=0` and `<BATCH>_PRODUCTION.json` has N records `published: true` with production `topicUrl`s (`https://preuni.voluntaria.pe/...`). Count them with a script; don't trust the log alone.

---

## 7. Phase E — validate production

**E1. Full validator.** Run `make_expected.js` on `<BATCH>_PRODUCTION.json` → `expected_prod.json`, then `validate_publish.rb` on production. Required:
- `rows=N topics=N solutions=N indexed=N`;
- no `truncated tag` lines (if B2 was applied);
- `duplicate questions ... 0`;
- `records with problems: 0`.

**E2. Render + images + MathJax 4.1, all topics.** Run as one backgrounded call (about 15 minutes for 180 topics):
- `node check_render.js https://preuni.voluntaria.pe $SCRATCH/prodpub/expected_prod.json` → `no problems` (all images 200, every formula compiled with 0 errors);
- `node shot_topic.js https://preuni.voluntaria.pe $SCRATCH/prodpub/expected_prod.json $SCRATCH/prodpub/shots_prod` → `no problems`;
- `python find_blank.py $SCRATCH/prodpub/shots_prod` → `blank 0` (retake any blank one with `shot_topic.js`).

Look at about 12 screenshots spread across the pruebas: every image-choice record, tables, special notation (circled operators, arrays, chemistry), and any record the review flagged. Compare them with the records (and the 👁 popup where the layout is unusual). For uni_2024_2 these were P1#01, #07, #10, #14, #15, #19, #20, #35, P2#15, #17, P3#27, #36, #39.

**E3. Search and filters (public, read-only):**
- `curl -s -H "Accept: application/json" "https://preuni.voluntaria.pe/preuni/buscar?universidad%5B%5D=<U>&anio%5B%5D=<YEAR>"` → `total` = N. Results come in pages of 100 (`truncado: true` means more pages; once the paging fix is deployed the response also has `siguiente` and `?offset=` gives the next page).
- `/preuni/opciones` lists `2024` under `anio`.
- Index rows = baseline + N.

**E4. Titles.** In rails, list the N topic titles. None may contain `upload:`, `<table`, `[FIG`, `\`, `$`, `array`, `matrix`, or `arrow` (the old `\rightarrow` bug). Duplicate-suffixed titles (` — N° x (UNI 2024-II)`) are expected for repeated instructions; count them.

**E5. Metrics untouched:** no new `preuni_eventos` from this session (same check as in C3). Anonymous events from someone else's test (e.g. topic 338): report them and remove them only if the user asks.

**E6. Optional human check:** ask the user to open 2–3 of the new topics in their own browser **while logged in as admin**, click "Mostrar clave", and open the solution thread.

---

## 8. Phase F — cleanup (ALWAYS run, also after a failure or a STOP after B3)

**F1.** Stop the production-pointed server (PID on port 3000) and start the normal one: PowerShell `Start-Process -FilePath "C:\Program Files\nodejs\node.exe" -ArgumentList "server.js" -WorkingDirectory "C:\Dev\GmatClubScrap" -WindowStyle Hidden`. Prove it is local again: `curl -s http://localhost:3000/api/topic-info/<a local topic id from the source batch>` returns that local title.

**F2. Remove this run's page-load traces** (after the last production page load, i.e. after E2/E6). Find this machine's public IP in the nginx log (`sudo grep -h ' /t/<a pilot topic id>' /var/discourse/shared/standalone/log/var-log/nginx/access.log | tail -3`, the `HeadlessChrome` lines). Write `/tmp/cleanup_views.json` = `{"apply": false, "date": "<UTC date of the page loads>", "groups": [{"ip": "<that IP>", "topic_ids": [<all N production topic ids>], "views": true}]}` and run `cleanup_views.rb`. Expected dry run: one `topic_views` row per topic, `sum(topics.views)` dropping by N (only by the rows that are ours), no `STOP`. Then set `"apply": true` and run it again; afterwards 0 HeadlessChrome events from that IP remain. If the page loads crossed midnight UTC, run it once per date. 2024-II: 180 view rows + 189 events removed.

**F3. Revoke and delete the API key** on production:
`ApiKey.where(description: 'TEMP bulk publish <BATCH> <YYYY-MM-DD>').each { |k| k.update!(revoked_at: Time.zone.now); k.destroy! }; puts ApiKey.where(description: 'TEMP bulk publish <BATCH> <YYYY-MM-DD>').count` must print 0.

**F3b.** Delete the key file: `rm "$SCRATCH/prodpub/prod_key.txt"`, then confirm it's gone. Remove the copied scripts and JSON from the production host (`~/`) and from the container's `/tmp`.

**F4.** `grep -n "^DISCOURSE_URL" .env` still shows `http://localhost:8080`.

**F5.** Keep `bulk_data/<BATCH>_PRODUCTION.json`: it holds the production topic ids, needed for any later fix. Do not commit it; commits are the user's call.

---

## 9. Report to the user

Lead with one outcome line (e.g. "UNI 2024-II is live on production: 180/180 published and verified, 0 problems"). Then:
- **Numbers:** published / failed / retried; topic id range; solutions; images; formulas compiled; search total; index rows before → after.
- **What changed on production:**
  - the backup file name;
  - `max_tag_length` old → new and the tags pre-created;
  - API key created (id) and revoked/deleted;
  - N new topics.
- **Fixes made to the batch files:** e.g. math delimiters (A4), in both the source and the production copy; any restamped records (D2).
- **Page-load traces removed** (F2): view rows and pageview events.
- **Still open, user decisions:** whatever this run left open, plus the items still open in memory (`bulk_pipeline.md`, `production_deployment.md`), e.g. S3 off-site backups.

Do not commit or push.

## 10. Memory update (end of session)

- `memory/bulk_pipeline.md`: "<BATCH> published to production <date>": count, topic id range, backup name, tag-length change, anything new learned.
- `memory/production_deployment.md`: question count on production (305 + N) and the backup.
- If `max_tag_length` changed, say so in both, because it affects every future batch.

---

## Appendix — scripts (copy verbatim with the Write tool)

### make_expected.js
```js
// node make_expected.js <batch file> <out.json>
// One row per published record: what the topic on Discourse must contain.
const fs = require('fs');
const [, , batchFile, outFile] = process.argv;
const D = JSON.parse(fs.readFileSync(batchFile, 'utf8'));
const slug = s => (s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim()
  .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
const mathCount = t => {
  t = t || '';
  const display = (t.match(/\$\$[\s\S]*?\$\$/g) || []).length;
  const inline = (t.replace(/\$\$[\s\S]*?\$\$/g, ' ').match(/\$[^$\n]+\$/g) || []).length;
  return display + inline;
};
const out = D.filter(r => r.published && r.topicId).map(r => ({
  id: r.id, topicId: r.topicId, numero: String(r.numero), clave: r.clave,
  universidad: r.universidad, tema: r.tema, anio: String(r.anio), convocatoria: r.convocatoria || '',
  modalidad: r.modalidad || '', tipo_area: r.tipo_area || '',
  tags: [String(r.numero), ...(r.subtemas || []), slug(r.modalidad), slug(r.tipo_area)].filter(Boolean),
  nFig: (r.figureImages || []).filter(Boolean).length,
  nChoiceImg: Object.values(r.choiceImages || {}).filter(Boolean).length,
  hasSolution: !!((r.solutionBody && r.solutionBody.trim()) || (r.solutionFigureImages || []).length),
  nSolFig: (r.solutionFigureImages || []).filter(Boolean).length,
  nMathOp: mathCount([r.body, ...Object.values(r.choices || {})].join('\n')),
  nMathSol: mathCount(r.solutionBody),
}));
fs.writeFileSync(outFile, JSON.stringify(out));
console.log(`expected rows: ${out.length} of ${D.length} records (unpublished: ${D.length - out.length})`);
```

### preflight.rb
```ruby
# rails runner /tmp/preflight.rb   (reads /tmp/expected.json built from the SOURCE batch)
# Read-only. Is this site ready to receive the batch?
require "json"
rows = JSON.parse(File.read("/tmp/expected.json"))
%w[discourse_math_enabled tagging_enabled max_tag_length max_tags_per_topic allow_duplicate_topic_titles
   min_topic_title_length max_topic_title_length].each { |s| puts "setting #{s}=#{SiteSetting.send(s).inspect}" }
max_tags = rows.map { |e| e["tags"].size }.max
puts "max tags on one record=#{max_tags} (limit #{SiteSetting.max_tags_per_topic})#{max_tags > SiteSetting.max_tags_per_topic ? '  <-- TOO MANY' : ''}"

rows.map { |e| e["universidad"] }.uniq.each do |u|
  parent = Category.find_by(name: u, parent_category_id: nil)
  temas = rows.select { |e| e["universidad"] == u }.map { |e| e["tema"] }.uniq
  missing = temas.reject { |t| parent && Category.exists?(name: t, parent_category_id: parent.id) }
  puts "parent category #{u}: #{parent ? "id #{parent.id}" : 'MISSING'} | temas in batch #{temas.size} | missing subcategories: #{missing.inspect}"
end

tags = rows.flat_map { |e| e["tags"] }.uniq.reject { |t| t =~ /\A\d+\z/ }
missing = tags - Tag.where(name: tags).pluck(:name)
long = missing.select { |t| t.length > SiteSetting.max_tag_length }
puts "non-number tags used #{tags.size} | missing on this site #{missing.size}: #{missing.inspect}"
puts "missing AND longer than max_tag_length=#{SiteSetting.max_tag_length} (would be TRUNCATED): #{long.inspect}"

rows.map { |e| [e["universidad"], e["anio"], e["convocatoria"]] }.uniq.each do |u, a, c|
  ids = TopicCustomField.where(name: "preuni_anio", value: a).pluck(:topic_id)
  n = Topic.where(id: ids, deleted_at: nil).count { |t| t.custom_fields["preuni_universidad"] == u && t.custom_fields["preuni_convocatoria"] == c }
  puts "topics already on this site for #{u} #{a}-#{c}: #{n}"
end
puts "baseline: index_rows=#{PreuniPreguntaIndice.count} max_topic_id=#{Topic.maximum(:id)} max_evento_id=#{PreuniEvento.maximum(:id).inspect}"
puts "latest backups: #{Dir.glob('/shared/backups/default/*').sort_by { |f| File.mtime(f) }.last(2).map { |f| "#{File.basename(f)} (#{File.size(f) / 1_000_000} MB)" }.inspect}"
```

### validate_publish.rb
```ruby
# rails runner /tmp/validate_publish.rb   (reads /tmp/expected.json)
# Read-only. Checks every published topic against what the batch record says it must contain.
require "json"
rows = JSON.parse(File.read("/tmp/expected.json"))
fails = Hash.new { |h, k| h[k] = [] }
stats = Hash.new(0)

rows.each do |e|
  id = e["id"]
  t = Topic.find_by(id: e["topicId"])
  if t.nil? || t.deleted_at
    fails[id] << "topic #{e['topicId']} missing or deleted"
    next
  end
  stats[:topics] += 1

  # category = universidad / tema
  cat = t.category
  parent = cat&.parent_category
  fails[id] << "category #{parent&.name}/#{cat&.name} != #{e['universidad']}/#{e['tema']}" unless cat&.name == e["tema"] && parent&.name == e["universidad"]

  # topic custom fields
  f = t.custom_fields
  { "preuni_clave" => e["clave"], "preuni_numero" => e["numero"], "preuni_universidad" => e["universidad"],
    "preuni_tema" => e["tema"], "preuni_anio" => e["anio"], "preuni_convocatoria" => e["convocatoria"],
    "preuni_modalidad" => e["modalidad"], "preuni_tipo_area" => e["tipo_area"] }.each do |k, v|
    next if v.to_s.empty? && f[k].to_s.empty?
    fails[id] << "#{k}=#{f[k].inspect} expected #{v.inspect}" unless f[k].to_s == v.to_s
  end

  # tags: bare number + subtemas + modalidad/tipo_area slugs; no legacy N°x / nX tags
  tag_names = t.tags.pluck(:name)
  missing = e["tags"] - tag_names
  # a NEW tag name longer than max_tag_length is cut when attached ("aptitud-y-humanidades" -> "...humanidade")
  truncated = missing.select { |x| tag_names.include?(x[0, SiteSetting.max_tag_length]) }
  truncated.each { |x| stats["truncated tag #{x} -> #{x[0, SiteSetting.max_tag_length]}"] += 1 }
  missing -= truncated
  fails[id] << "missing tags #{missing.inspect} (has #{tag_names.inspect})" if missing.any?
  legacy = tag_names.grep(/\A(n|N°|N\.º)\s*\d+\z/)
  fails[id] << "legacy number tags #{legacy.inspect}" if legacy.any?

  # title hygiene
  fails[id] << "bad title #{t.title.inspect}" if t.title =~ /upload:|<table|\[FIG|\\[a-zA-Z]|\$|\barray\b|\bmatrix\b/

  # first post
  op = t.first_post
  raw, cooked = op.raw, op.cooked
  fails[id] << "OP raw has [FIG:n]" if raw.include?("[FIG:")
  %w[A B C D E].each { |l| fails[id] << "OP missing **(#{l})**" unless raw.include?("**(#{l})**") }
  fails[id] << "OP cooked has unresolved upload://" if cooked.include?("upload://")
  imgs = cooked.scan(/<img(?![^>]*class="emoji)/).size
  want = e["nFig"] + e["nChoiceImg"]
  fails[id] << "OP images #{imgs} < expected #{want}" if imgs < want
  math = cooked.scan(/class="math"/).size
  fails[id] << "OP math spans #{math} != expected #{e['nMathOp']}" if math != e["nMathOp"]
  stats[:op_images] += imgs

  # solution reply
  sol = t.posts.where(post_number: 2, deleted_at: nil).first
  if e["hasSolution"]
    if sol.nil?
      fails[id] << "solution reply missing"
    else
      fails[id] << "solution preuni_post_type=#{sol.custom_fields['preuni_post_type'].inspect}" unless sol.custom_fields["preuni_post_type"] == "solucion"
      fails[id] << "solution cooked has unresolved upload://" if sol.cooked.include?("upload://")
      simgs = sol.cooked.scan(/<img(?![^>]*class="emoji)/).size
      fails[id] << "solution images #{simgs} < expected #{e['nSolFig']}" if simgs < e["nSolFig"]
      smath = sol.cooked.scan(/class="math"/).size
      fails[id] << "solution math spans #{smath} != expected #{e['nMathSol']}" if smath != e["nMathSol"]
      fails[id] << "solution raw has [FIG:n]" if sol.raw.include?("[FIG:")
      stats[:solutions] += 1
    end
  elsif sol
    fails[id] << "unexpected reply #2 on a key-only record"
  end
  fails[id] << "extra posts (#{t.posts.where(deleted_at: nil).count})" if t.posts.where(deleted_at: nil).count > (e["hasSolution"] ? 2 : 1)

  # search index row
  ix = PreuniPreguntaIndice.find_by(topic_id: t.id, post_id: op.id) || PreuniPreguntaIndice.find_by(topic_id: t.id)
  if ix.nil?
    fails[id] << "no preuni_preguntas_indice row"
  else
    { universidad: e["universidad"], anio: e["anio"].to_i, convocatoria: e["convocatoria"], modalidad: e["modalidad"],
      tipo_area: e["tipo_area"], tema: e["tema"] }.each do |k, v|
      fails[id] << "index #{k}=#{ix.send(k).inspect} expected #{v.inspect}" unless ix.send(k).to_s == v.to_s
    end
    stats[:indexed] += 1
  end
end

# duplicates: the same universidad/anio/convocatoria/numero/tema published twice
keys = rows.map { |e| [e["universidad"], e["anio"], e["convocatoria"], e["tema"], e["numero"]] }
dupe_topics = TopicCustomField.where(name: "preuni_numero", value: rows.map { |e| e["numero"] }.uniq)
  .joins("JOIN topics ON topics.id = topic_custom_fields.topic_id AND topics.deleted_at IS NULL").pluck(:topic_id)
seen = Hash.new { |h, k| h[k] = [] }
Topic.where(id: dupe_topics).each do |tp|
  cf = tp.custom_fields
  k = [cf["preuni_universidad"], cf["preuni_anio"], cf["preuni_convocatoria"], cf["preuni_tema"], cf["preuni_numero"]]
  seen[k] << tp.id if keys.include?(k)
end
dups = seen.select { |_, v| v.size > 1 }

puts "rows=#{rows.size} topics=#{stats[:topics]} solutions=#{stats[:solutions]} indexed=#{stats[:indexed]} op_images=#{stats[:op_images]}"
stats.each { |k, v| puts "#{k}: #{v} topics" if k.to_s.start_with?("truncated") }
puts "duplicate questions (same universidad/anio/convocatoria/tema/numero): #{dups.size}"
dups.first(10).each { |k, v| puts "  DUP #{k.inspect} -> topics #{v.inspect}" }
puts "records with problems: #{fails.size}"
fails.first(60).each { |id, msgs| puts "  #{id}: #{msgs.join(' | ')}" }
```

### check_math_boundaries.js
```js
// node check_math_boundaries.js <batch.json>
// discourse-math only accepts an inline $...$ when the char BEFORE the opening $
// and the char AFTER the closing $ are whitespace, punctuation, or the line edge
// (markdown-it isWhiteSpace / isMdAsciiPunct / isPunctChar). "$75^{\circ}$C" or
// "CO$_2$" therefore do NOT render on Discourse, even though the bulk-preview
// popup (client-side MathJax) shows them fine. Lists every offending span.
const fs = require('fs');
const D = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const safe = ch => ch === undefined || ch === '' || /[\s!-\/:-@\[-`{-~\u2000-\u206F\u2E00-\u2E7F\u00A1-\u00BF\u3000-\u303F«»“”‘’¿¡]/.test(ch);
function offenders(text) {
  const out = [];
  if (!text) return out;
  // blank out display math first, then walk inline $...$ pairs per paragraph
  const t = text.replace(/\$\$[\s\S]*?\$\$/g, m => ' '.repeat(m.length));
  for (const para of t.split(/\n\s*\n/)) {
    const re = /\$([^$\n]+?)\$/g; let m;
    while ((m = re.exec(para))) {
      const before = para[m.index - 1], after = para[m.index + m[0].length];
      if (!safe(before) || !safe(after) || (before === '$') || (after === '$'))
        out.push(para.slice(Math.max(0, m.index - 12), m.index + m[0].length + 12).replace(/\n/g, ' '));
    }
  }
  return out;
}
let n = 0;
for (const r of D) {
  const fields = { body: r.body, solution: r.solutionBody, ...Object.fromEntries(Object.entries(r.choices || {}).map(([k, v]) => ['choice ' + k, v])) };
  for (const [f, txt] of Object.entries(fields)) {
    for (const o of offenders(txt)) { n++; console.log(`${r.id} [${f}] …${o}…`); }
  }
}
console.log(`offending inline math spans: ${n}`);
```

### check_render.js
```js
// node check_render.js <baseUrl> <ids.json | expected.json> [--shots dir]
// Read-only, anonymous. For every topic: fetch /t/<id>.json, collect the cooked
// HTML of all posts, check every <img> URL answers 200, then load ONE topic page
// in headless Chromium and run every formula through that site's own MathJax
// (MathJax.tex2chtmlPromise) -- catches TeX the production MathJax can't render,
// in solutions too (anonymous visitors don't see solution posts on the page).
const { chromium } = require('C:/Users/smart/AppData/Local/npm-cache/_npx/9833c18b2d85bc59/node_modules/playwright-core');
const fs = require('fs');
const path = require('path');

const [, , BASE, idsFile] = process.argv;
const shotsDir = process.argv.includes('--shots') ? process.argv[process.argv.indexOf('--shots') + 1] : null;
const raw = JSON.parse(fs.readFileSync(idsFile, 'utf8'));
const ids = raw.map(x => (typeof x === 'object' ? x.topicId : x));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const decode = s => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
const abs = u => (u.startsWith('//') ? new URL(BASE).protocol + u : u.startsWith('/') ? BASE + u : u);

async function getJson(url) {
  for (let i = 0; i < 6; i++) {
    const r = await fetch(url, { headers: { Accept: 'application/json' } });
    if (r.status === 429) { await sleep(10000); continue; }
    if (!r.ok) throw new Error(`${url} -> ${r.status}`);
    return r.json();
  }
  throw new Error(`${url} -> still 429`);
}

(async () => {
  const problems = [], formulas = [];
  let images = 0;
  for (const id of ids) {
    let t;
    try { t = await getJson(`${BASE}/t/${id}.json`); } catch (e) { problems.push(`topic ${id}: ${e.message}`); continue; }
    for (const p of t.post_stream.posts) {
      const cooked = p.cooked || '';
      if (/upload:\/\/|\[FIG:\d+\]/.test(cooked)) problems.push(`topic ${id} post ${p.post_number}: unresolved upload:// or [FIG:n]`);
      for (const m of cooked.matchAll(/<img[^>]+src="([^"]+)"/g)) {
        if (/emoji|avatar|user_avatar/.test(m[1])) continue;
        images++;
        const r = await fetch(abs(m[1]), { method: 'GET' });
        if (r.status !== 200) problems.push(`topic ${id} post ${p.post_number}: image ${r.status} ${m[1]}`);
      }
      for (const m of cooked.matchAll(/<span class="math">([\s\S]*?)<\/span>/g)) formulas.push({ id, post: p.post_number, tex: decode(m[1]), display: false });
      for (const m of cooked.matchAll(/<div class="math">([\s\S]*?)<\/div>/g)) formulas.push({ id, post: p.post_number, tex: decode(m[1]).trim(), display: true });
    }
    await sleep(300);
  }

  const browser = await chromium.launch({ executablePath: 'C:/Users/smart/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe' });
  const page = await browser.newPage({ viewport: { width: 1100, height: 900 } });
  // Never pollute production metrics/view counts: drop the MVP-metrics beacon
  // (/preuni/evento, which logs anonymous pregunta_vista) and the timing/view tracking.
  let blocked = 0;
  await page.route('**/*', route => {
    const req = route.request();
    if (/\/preuni\/evento|\/topics\/timings|\/message-bus\//.test(req.url())) { blocked++; return route.abort(); }
    const h = { ...req.headers() };
    delete h['discourse-track-view']; delete h['discourse-track-view-topic-id'];
    return route.continue({ headers: h });
  });
  const withMath = formulas.length ? formulas[0].id : ids[0];
  await page.goto(`${BASE}/t/${withMath}`, { waitUntil: 'domcontentloaded' }); await page.waitForSelector('#post_1 .cooked', { timeout: 30000 });
  let mathErrors = 0;
  if (formulas.length) {
    await page.waitForFunction(() => window.MathJax && window.MathJax.tex2chtmlPromise, null, { timeout: 30000 });
    const version = await page.evaluate(() => window.MathJax.version);
    const errs = await page.evaluate(async list => {
      const out = [];
      for (const f of list) {
        try {
          const n = await MathJax.tex2chtmlPromise(f.tex, { display: f.display });
          const e = n.querySelector('mjx-merror');
          if (e) out.push({ ...f, err: e.getAttribute('data-mjx-error') || e.textContent });
          // an undefined command raises no mjx-merror: MathJax just draws it in red
          else if (n.querySelector('[style*="red"], [mathcolor="red"]')) out.push({ ...f, err: 'undefined command (shown in red)' });
        } catch (x) { out.push({ ...f, err: String(x) }); }
      }
      return out;
    }, formulas);
    mathErrors = errs.length;
    console.log(`MathJax ${version}: ${formulas.length} formulas, ${errs.length} errors`);
    errs.slice(0, 30).forEach(e => problems.push(`topic ${e.id} post ${e.post}: MathJax error "${e.err}" in ${JSON.stringify(e.tex).slice(0, 120)}`));
  }
  if (shotsDir) {
    fs.mkdirSync(shotsDir, { recursive: true });
    for (const id of ids.slice(0, 400)) {
      await page.goto(`${BASE}/t/${id}`, { waitUntil: 'domcontentloaded' }); await page.waitForSelector('#post_1 .cooked', { timeout: 30000 });
      await page.waitForTimeout(1500);
      const h = await page.evaluate(() => ({
        merror: document.querySelectorAll('#post_1 mjx-merror').length,
        broken: [...document.querySelectorAll('#post_1 .cooked img')].filter(i => i.complete && !i.naturalWidth).length,
        rawDollar: /\$[^$\s][^$]*\$/.test(document.querySelector('#post_1 .cooked')?.innerText || ''),
      }));
      if (h.merror || h.broken || h.rawDollar) problems.push(`topic ${id} page: ${JSON.stringify(h)}`);
      await page.locator('#post_1').screenshot({ path: path.join(shotsDir, `${id}.png`) }).catch(() => {});
    }
  }
  await browser.close();
  console.log(`topics ${ids.length} | images checked ${images} | formulas ${formulas.length} | math errors ${mathErrors} | tracking requests blocked ${blocked}`);
  console.log(problems.length ? 'PROBLEMS:\n' + problems.join('\n') : 'no problems');
})().catch(e => { console.error('FATAL', e); process.exit(1); });
```

### pick_pilot.js
```js
// node pick_pilot.js <batch.json>  -- rank records by how many upload/render paths they exercise
const fs = require('fs');
const D = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const mathCount = t => {
  t = t || '';
  const display = (t.match(/\$\$[\s\S]*?\$\$/g) || []).length;
  const inline = (t.replace(/\$\$[\s\S]*?\$\$/g, ' ').match(/\$[^$\n]+\$/g) || []).length;
  return display + inline;
};
const rows = D.filter(r => !r.published).map(r => {
  const opText = [r.body, ...Object.values(r.choices || {})].join('\n');
  return {
    id: r.id,
    fig: (r.figureImages || []).filter(Boolean).length,
    chImg: Object.values(r.choiceImages || {}).filter(Boolean).length,
    solFig: (r.solutionFigureImages || []).filter(Boolean).length,
    mathOp: mathCount(opText), mathSol: mathCount(r.solutionBody),
    display: /\$\$/.test(opText + (r.solutionBody || '')),
    table: /\n\|.*\|/.test(opText),
  };
});
const score = x => (x.fig > 0) + (x.chImg > 0) + (x.solFig > 0) + (x.mathOp > 0) + (x.mathSol > 0) + x.display;
rows.sort((a, b) => score(b) - score(a) || (b.mathOp + b.mathSol) - (a.mathOp + a.mathSol));
console.log('id | fig chImg solFig mathOp mathSol display table | score');
rows.slice(0, 15).forEach(x => console.log(`${x.id} | ${x.fig} ${x.chImg} ${x.solFig} ${x.mathOp} ${x.mathSol} ${x.display} ${x.table} | ${score(x)}`));
```

### shot_topic.js
```js
// node shot_topic.js <baseUrl> <ids.json | expected.json> <outDir>
// Screenshot #post_1 of each topic, waiting until its images are decoded and MathJax has typeset.
// Same tracking blocks as check_render.js (metrics beacon, timings, message-bus, track-view headers).
const { chromium } = require('C:/Users/smart/AppData/Local/npm-cache/_npx/9833c18b2d85bc59/node_modules/playwright-core');
const fs = require('fs');
const path = require('path');
const [, , BASE, idsFile, outDir] = process.argv;
const ids = JSON.parse(fs.readFileSync(idsFile, 'utf8')).map(x => (typeof x === 'object' ? x.topicId : x));
(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ executablePath: 'C:/Users/smart/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe' });
  // tall viewport: posts taller than the viewport came out blank in element screenshots
  const page = await browser.newPage({ viewport: { width: 1100, height: 3000 } });
  await page.route('**/*', route => {
    const req = route.request();
    if (/\/preuni\/evento|\/topics\/timings|\/message-bus\//.test(req.url())) return route.abort();
    const h = { ...req.headers() };
    delete h['discourse-track-view']; delete h['discourse-track-view-topic-id'];
    return route.continue({ headers: h });
  });
  const problems = [];
  for (const id of ids) {
    await page.goto(`${BASE}/t/${id}`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#post_1 .cooked', { timeout: 30000 });
    // images decoded + every .math span typeset (or none present), up to 30 s
    await page.waitForFunction(() => {
      const c = document.querySelector('#post_1 .cooked');
      if (!c) return false;
      const imgsDone = [...c.querySelectorAll('img')].every(i => i.complete);
      const math = c.querySelectorAll('.math').length;
      const typeset = c.querySelectorAll('mjx-container').length;
      return imgsDone && (math === 0 || typeset >= math);
    }, null, { timeout: 30000 }).catch(() => problems.push(`topic ${id}: wait for images/MathJax timed out`));
    await page.locator('#post_1').scrollIntoViewIfNeeded();
    await page.waitForTimeout(800);
    const h = await page.evaluate(() => ({
      math: document.querySelectorAll('#post_1 .cooked .math').length,
      typeset: document.querySelectorAll('#post_1 .cooked mjx-container').length,
      merror: document.querySelectorAll('#post_1 mjx-merror').length,
      broken: [...document.querySelectorAll('#post_1 .cooked img')].filter(i => i.complete && !i.naturalWidth).length,
      rawDollar: /\$[^$\s][^$]*\$/.test(document.querySelector('#post_1 .cooked')?.innerText || ''),
    }));
    console.log(`topic ${id}: ${JSON.stringify(h)}`);
    if (h.merror || h.broken || h.rawDollar) problems.push(`topic ${id} page: ${JSON.stringify(h)}`);
    await page.locator('#post_1').screenshot({ path: path.join(outDir, `${id}.png`) });
  }
  await browser.close();
  console.log(problems.length ? 'PROBLEMS:\n' + problems.join('\n') : 'no problems');
})().catch(e => { console.error('FATAL', e); process.exit(1); });
```

### find_blank.py
```python
# python find_blank.py <shots dir>  -- list screenshots whose area below the 60px sticky header is (almost) empty
import sys, os
from PIL import Image

d = sys.argv[1]
blank = []
for f in sorted(os.listdir(d)):
    if not f.endswith('.png'):
        continue
    im = Image.open(os.path.join(d, f)).convert('L')
    w, h = im.size
    body = im.crop((0, 60, w, h))
    # pixels clearly darker than the cream background = text, figures, borders
    dark = sum(1 for p in body.getdata() if p < 180)
    ratio = dark / max(1, body.size[0] * body.size[1])
    if ratio < 0.002:
        blank.append((f, h, round(ratio, 5)))
print(f"checked {len([f for f in os.listdir(d) if f.endswith('.png')])} | blank {len(blank)}")
for f, h, r in blank:
    print(f"  {f} height {h} dark-ratio {r}")
```

### cleanup_views.rb
```ruby
# rails runner /tmp/cleanup_views.rb   (reads /tmp/cleanup_views.json)
# Removes the traces of our own headless render checks: browser pageview events (+ their scores and
# session engagements), and -- for groups with "views": true -- the anonymous topic view each check
# counted (topic_views row, topics.views, topic_view_stats.anonymous_views).
# Daily rollups (browser_pageview_*_daily_rollups, category_activity_daily_rollups) are rebuilt from
# these base tables by scheduled jobs every 10 minutes, so they are not edited here.
# "apply": false = dry run (prints only). Everything runs in one transaction.
require "json"
cfg = JSON.parse(File.read("/tmp/cleanup_views.json"))
apply = cfg["apply"] == true
date = Date.parse(cfg["date"])
puts "mode: #{apply ? 'APPLY' : 'DRY RUN'} | date #{date} | topic_view_duration_hours #{SiteSetting.topic_view_duration_hours}"
stop = false

ActiveRecord::Base.transaction do
  cfg["groups"].each do |g|
    ip = g["ip"]
    ids = g["topic_ids"].map(&:to_i)
    ev = BrowserPageviewEvent.where("host(ip_address) = ?", ip).where("user_agent LIKE ?", "%HeadlessChrome%")
      .where("created_at::date = ?", date).where(topic_id: ids)
    ev_ids = ev.pluck(:id)
    first, last = ev.minimum(:created_at), ev.maximum(:created_at)
    sessions = ev.distinct.pluck(:session_id).compact
    shared = BrowserPageviewEvent.where(session_id: sessions).where.not(id: ev_ids).distinct.pluck(:session_id)
    eng_ids = BrowserPageviewSessionEngagement.where(session_id: sessions - shared).pluck(:id)
    score_ids = BrowserPageviewEventScore.where(event_id: ev_ids).pluck(:id)
    puts "[#{ip}] topics given #{ids.size} | headless events #{ev_ids.size} on #{ev.distinct.count(:topic_id)} topics (#{first} .. #{last})"
    puts "  event scores #{score_ids.size} | session engagements #{eng_ids.size} (sessions #{sessions.size}, shared with other events #{shared.size})"

    tv_topics = []
    if g["views"]
      if first && last && (last - first) > SiteSetting.topic_view_duration_hours.hours
        puts "  STOP: headless loads span more than topic_view_duration_hours -> a topic may have been counted twice"
        stop = true
        next
      end
      human = BrowserPageviewEvent.where("host(ip_address) = ?", ip).where(user_id: nil)
        .where("user_agent NOT LIKE ?", "%HeadlessChrome%").where(topic_id: ids).distinct.pluck(:topic_id)
      tv_topics = DB.query_single(<<~SQL, ids: ids - human, ip: ip, d: date)
        SELECT topic_id FROM topic_views
        WHERE topic_id IN (:ids) AND user_id IS NULL AND viewed_at = :d AND host(ip_address) = :ip
      SQL
      headless_topics = ev.distinct.pluck(:topic_id)
      no_event = tv_topics - headless_topics
      low = DB.query(<<~SQL, ids: tv_topics.presence || [0], d: date)
        SELECT t.id, t.views, s.anonymous_views
        FROM topics t LEFT JOIN topic_view_stats s ON s.topic_id = t.id AND s.viewed_at = :d
        WHERE t.id IN (:ids) AND (t.views < 1 OR COALESCE(s.anonymous_views, 0) < 1)
      SQL
      puts "  topic_views rows to remove #{tv_topics.size} | skipped (human anonymous events from this IP) #{human.inspect}"
      puts "  view rows with no headless event (left alone) #{no_event.inspect}" if no_event.any?
      if low.any?
        puts "  STOP: counters already at 0 for #{low.map(&:id).inspect}"
        stop = true
        next
      end
      tv_topics -= no_event
      before = DB.query("SELECT COALESCE(SUM(views),0) v FROM topics WHERE id IN (:ids)", ids: ids).first.v
      puts "  sum(topics.views) over the group before #{before} -> after #{before - tv_topics.size}"
    end

    next unless apply && !stop
    DB.exec("DELETE FROM browser_pageview_event_scores WHERE id IN (:x)", x: score_ids) if score_ids.any?
    DB.exec("DELETE FROM browser_pageview_session_engagements WHERE id IN (:x)", x: eng_ids) if eng_ids.any?
    DB.exec("DELETE FROM browser_pageview_events WHERE id IN (:x)", x: ev_ids) if ev_ids.any?
    if tv_topics.any?
      DB.exec(<<~SQL, t: tv_topics, ip: ip, d: date)
        DELETE FROM topic_views WHERE topic_id IN (:t) AND user_id IS NULL AND viewed_at = :d AND host(ip_address) = :ip
      SQL
      DB.exec("UPDATE topics SET views = GREATEST(views - 1, 0) WHERE id IN (:t)", t: tv_topics)
      DB.exec("UPDATE topic_view_stats SET anonymous_views = GREATEST(anonymous_views - 1, 0) WHERE topic_id IN (:t) AND viewed_at = :d", t: tv_topics, d: date)
      DB.exec("DELETE FROM topic_view_stats WHERE topic_id IN (:t) AND viewed_at = :d AND anonymous_views = 0 AND logged_in_views = 0", t: tv_topics, d: date)
    end
    puts "  applied"
  end
  raise ActiveRecord::Rollback if stop
end
puts stop ? "STOPPED: nothing changed" : (apply ? "DONE" : "dry run only, nothing changed")
```
