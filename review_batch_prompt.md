# Batch review prompt — compare a bulk batch against its source PDF and fix it

Use: start a new Claude Code session in `C:\Dev\GmatClubScrap` and say:

> Read `review_batch_prompt.md` and run it for BATCH=`uni_2025_2`, PDF_DIR=`pdfs/parsed/UNI 2025-II`, RANGE=`all`.

(`uni_2024_2` P1#15 → P3#40 and `uni_2022_1` (all 264) were reviewed on 2026-10-04, `uni_2021_1` (all 75) on 2026-10-05; `uni_2024_2` P1#1–14 were validated by the user before that.)

It works for any batch: BATCH is the batch id shown in the preview's batch selector (the file is `bulk_data/<BATCH>.json`, except `default`, which is `bulk_review.json` at the repo root); PDF_DIR is the folder with that exam's PDF; RANGE can be `all`, one prueba (`P2`), or a span (`P1#15 → P3#40`). The batch must already be built (the upload session builds it). If the batch was already published, fixes here change the batch file only, not the live topics; list which published questions changed so the upload session can update them.

---

## Your job

You are reviewing an already-built question batch for PreUni (a Discourse-based question bank for Peruvian university admission exams). The batch was produced by OCR (PaddleOCR-VL) plus automated fixes, so it can still contain errors. For every question in RANGE you will:

1. Look at the question **and** its solution in the original PDF.
2. Look at how the record renders in the bulk preview popup (it mimics the real published PreUni question page).
3. Run **three independent review passes** (below), each one re-reading the PDF image from scratch — not from memory of the previous pass.
4. Fix every confirmed difference directly in the batch file, re-render, and confirm the fix.
5. Log everything you found and changed.

The reference is always the PDF. The goal is that a student sees exactly what the official exam shows: same text, same notation, same figures, same choices, correct answer key.

## Hard rules

- **Never publish.** Do not call `/api/publish`, `/api/publish-linked-question`, `publish_to_discourse.js`, or the "Publicar pendientes" button. Publishing needs the user's explicit approval in the *upload* session, not this one.
- **Never commit, push, or touch production** (`preuni.voluntaria.pe`, ssh).
- **One owner per batch file:** while you run, you are the only writer of `bulk_data/<BATCH>.json`. Re-read it from disk before every edit (the user may also save fixes from the composer).
- **Back up once before your first edit**, *outside* `bulk_data/` (a copy inside `bulk_data/` shows up as a fake batch in the preview): copy to your scratchpad as `<BATCH>.before_review.json`.
- **Respect the user's edits:** records with `"manuallyFixed": true` were already corrected by the user. Review them, but only change them for a clear, PDF-proven error, and call it out in the report.
- **Don't change** `id`, `prueba`, or any `published`/`topicId` fields.
- **Edit with scripts, not shell one-liners.** LaTeX backslashes get mangled when Python is inlined in bash/PowerShell heredocs (`\b` becomes a backspace and so on). Write each edit script to a `.py` file in your scratchpad (with the Write tool, not a heredoc), use raw strings (`r'...'`), and replace exact strings with an assertion that the old text occurs exactly once. Print the target fields with `json.dumps(...)` first and copy the exact old text from that output. Never build replacements with `re.sub` + a non-raw replacement string (it doubles or eats backslashes).
- **Save in the file's own format:** `json.dumps(data, ensure_ascii=False, indent=2)`, UTF-8, `\n` line endings, no trailing newline (check what the existing file does before the first save).
- Ask the user only when the PDF itself is ambiguous (unreadable scan, or a probable typo in the official document). Don't silently "improve" the official wording: keep the exam's own typos unless they are clearly OCR damage.

## Setup

1. Composer/preview server (serves `bulk-preview.html` and the batch API). Check `http://localhost:3000/api/status`. If it's down, start it **with an explicit working directory** (otherwise static files 404):
   `Start-Process -FilePath node -ArgumentList "C:\Dev\GmatClubScrap\server.js" -WorkingDirectory "C:\Dev\GmatClubScrap" -WindowStyle Hidden`
2. Preview: `http://localhost:3000/bulk-preview.html?batch=<BATCH>`. The Playwright browser can reach `localhost:3000` (it cannot reach local Discourse on :8080, and you don't need it). The server can stop between sessions (or overnight): if the page gives `ERR_CONNECTION_REFUSED`, restart it with the command above.
3. Source files in `PDF_DIR`: the official PDF, the OCR `.json`/`.md`, `images/` (OCR crops), and `images_hd/` (216-dpi crops re-rendered from the PDF, plus any `pNNN_manual_*.jpg`).
4. Python has PyMuPDF (`import pymupdf`) and Pillow.
5. Playwright's `browser_run_code_unsafe` can load code from a file (`filename`), but only from inside the repo: write generated scripts to `.playwright-mcp/` (allowed and gitignored), not to the scratchpad. Screenshots *can* be saved to the scratchpad.

### Tooling that paid off (build it once, in the first minutes)

- **Region locator:** from the text layer, find every question/solution start (`"N."` lines at the column's left margin; mind that 1-digit and 3-digit numbers sit at slightly different x), split pages into columns, and store each question's and solution's region as a list of `(page, rect)` segments (a question can continue in the next column/page). Everything else builds on it.
- **Word diff:** normalize the PDF text of each region (accents) and diff its words against `body` + `choices` (and the solution against `solutionBody`). It finds OCR typos, lost blanks, truncated choices and leaked headings in seconds; then confirm each hit on the image.
- **Answer keys up front:** one script comparing every `clave` with the PDF's "Respuesta X" for the whole RANGE, and checking that every `solutionBody` ends with "Respuesta X".
- **One review image per question:** PDF question crop above the PDF solution crop on the left, the popup screenshot on the right, in a single PNG. One Read per question instead of three.
- **Popup screenshots:** the popup is a scrolling overlay, so a plain screenshot is clipped. Before `.rq-page.screenshot()`, set the viewport height to `#rqOverlay.scrollHeight + 40` (cap ~6000), then reset it.
- **A batch-generated popup script** (list of ids → `.playwright-mcp/pop_run.js`) that returns health + `<h1>` title for every id; run it with `SHOT=false` over the whole RANGE at the start and at the end.
- **A lint script** run at the end over the whole RANGE (see "Final sweep").
- **Edit helper** (`fixlib.py`): load/save the batch, `rep(record, field, old, new)` asserting exactly one occurrence, `img(name)` → data URL, a log line per change (`edit_log.txt`), and a check that `[FIG:n]` indices are contiguous.

### Batch record format (`bulk_data/<BATCH>.json`, a JSON array, 2-space indent, UTF-8 not escaped)

```
id                 "p1-RAZONAMIENTO_MATEMÁTICO-14"   (p<prueba>-<materia>-<NN>)
prueba, numero     1, 14
materiaHeader      "RAZONAMIENTO MATEMÁTICO"
tema               category name, e.g. "Razonamiento Matemático", "Álgebra", "Física"
subtemas           list of slugs from the composer's SUB_TEMAS (question-composer-prototype.html)
universidad, anio, convocatoria   "UNI" | "UNMSM", "2024", "II"   (convocatoria = bare roman numeral; two-shift exams use "I-Mañana" / "I-Tarde", traslado "I" — user decision 2026-10-04)
modalidad, tipo_area              "Ordinario" | "Traslado" ...;
                                  UNI: "Aptitud y Humanidades" (Prueba 1) | "Matemática" (Prueba 2) | "Física-Química" (Prueba 3)
                                  UNMSM: "Área A" ... "Área E"
clusterId, clusterRole             reading-passage clusters (UNMSM): one "root" topic + "linked" questions
body               markdown; math in $...$ / $$...$$; figures as [FIG:n] markers
figureImages       list of data URLs; [FIG:n] = figureImages[n]
choices            {"A": "...", ... "E": "..."}   text/LaTeX; "" when the choice is an image
choiceImages       {"A": "data:image/jpeg;base64,..."}   image choices
clave              "C"   the answer key
solutionBody, solutionFigureImages   same conventions as body/figureImages
needsReview, manuallyFixed, oaMethod, classificationMethod   bookkeeping (leave alone)
```

How it will be published (so it's what the popup shows): the post is `body` (each `[FIG:n]` becomes an image on its own line) followed by one line per choice, `**(A)** text` or `**(A)** ![](image)`. The solution becomes a reply. Markdown rules apply: a blank line starts a new paragraph, so **math must never span a blank line**.

## Locating a question in the PDF

- Questions are in "Enunciados de la primera/segunda/tercera prueba"; solutions in "Solución de la … prueba". The printed page numbers in the table of contents are offset from PDF page numbers, so find the offset once.
- If the page has a text layer (`page.get_text()` returns real text), find `"N. "` at the start of a line. Two-column pages read left column then right. LaTeX-typeset PDFs split accents ("n´umero"): normalize `´a→á`, `˜n→ñ`, `¨u→ü` before comparing.
- Scanned pages (text layer is empty or only the running header) must be located visually.
- Render what you need with PyMuPDF and **look at it** (Read the PNG):
  ```python
  import pymupdf
  doc = pymupdf.open(PDF)
  pix = doc[page_index].get_pixmap(dpi=130, clip=pymupdf.Rect(x0, y0, x1, y1))   # PDF points
  pix.save(r'<scratchpad>\q14.png')
  ```
  OCR bounding boxes (in OCR crop filenames `img_in_image_box_x1_y1_x2_y2`) are in PDF points × 2.
- Render the popup the same way every time:
  ```js
  await p.goto('http://localhost:3000/bulk-preview.html?batch=<BATCH>');
  await p.waitForSelector('.qrow');
  const idx = await p.evaluate(id => DATA.findIndex(r => r.id === id), RECORD_ID);
  await p.evaluate(i => openRealPreview(i), idx);
  await p.waitForTimeout(2500);
  if (await p.evaluate(() => document.getElementById('rqSol')?.classList.contains('rq-hidden')))
    await p.click('.preuni-hilo-btn');        // open the solution thread if it's collapsed
  await p.click('.preuni-spoiler-btn >> nth=0');  // "Mostrar clave"
  await p.waitForTimeout(1500);
  const h = await p.evaluate(() => document.getElementById('rqOverlay').scrollHeight);
  await p.setViewportSize({ width: 900, height: Math.min(h + 40, 6000) });   // the overlay scrolls: grow the viewport or the shot is clipped
  await p.locator('.rq-page').screenshot({ path: '<scratchpad>/rq.png' });
  await p.setViewportSize({ width: 900, height: 1200 });
  const health = await p.evaluate(() => ({
    mathErrors: document.querySelectorAll('#rqContent mjx-merror').length,
    // an unknown command (\textcircled, \xleftrightarrow, \textsuperscript…) renders as red text, NOT as mjx-merror
    undefinedMacros: document.querySelectorAll('#rqContent mjx-assistive-mml [mathcolor="red"]').length,
    rawLatex: /\$|\\[a-zA-Z]+\{|\[FIG:\d+\]/.test(document.getElementById('rqContent').innerText),
    brokenImgs: [...document.querySelectorAll('#rqContent img')].filter(i => !i.complete || !i.naturalWidth).length,
  }));
  ```
  After editing the batch file, reload the page (DATA is loaded once per page load).

## Independent OCR (PaddleOCR-VL 1.6 MCP)

If the MCP server `paddleocr` is connected (check `/mcp`; the tool is `mcp__paddleocr__paddleocr_vl`; if it's listed as deferred, load it with ToolSearch `paddleocr`), use it as a **second, independent reading**, never as the source of truth:

- **When:**
  - every question whose PDF page is a scan (no text layer), once per question, in Pass 1;
  - wherever the batch text and the page image disagree, or the scan is hard to read;
  - to get LaTeX for a formula you need to retype.
- **Never send the whole PDF.** Send only what's in question: a tight crop of the region, or at most the single page(s) involved, rendered to PNG. If several disputes sit on the same page, one page render is cheaper than many crops.
- **How:** crop the region (or render the page) from the PDF at 216 dpi to a PNG in your scratchpad, then call the tool with the **absolute path**:
  `paddleocr_vl(input_data="C:\\...\\scratchpad\\p1q22_stem.png", file_type="image", output_mode="simple", return_images=false)`.
  It returns markdown with `$...$` LaTeX. `output_mode="detailed"` returns JSON with positions, but you rarely need it.
- **Judging:** compare its text with the record. Where they differ, look at the image again and decide; the PDF image wins. Its LaTeX can carry the same kinds of errors listed below (`\bigcirc t`, `\sin`, Spanish words translated to English), so clean them the same way.
- **Cost:** each call uses the AI Studio quota. Crop tightly, call once per region, and cache the result in your scratchpad (`ocr_cache/<crop name>.md`) so a pass never re-OCRs the same crop.
- If the tool isn't connected, continue without it: PDF text layer, plus close visual reading at higher dpi (render 200–300 dpi crops of small text and formulas). If ToolSearch `paddleocr` finds nothing, the server most likely failed to connect when the session started (first-launch `uvx` package resolution can exceed the MCP connect timeout; `claude mcp list` then shows ✘, and ✔ once the cache is warm). Ask the user to run `/mcp` → reconnect (or restart the session) before you start; if it still isn't there, say so in the report and continue.

## The three review passes (per question, each against the PDF image)

### Pass 1 — Text fidelity (stem, statements, choices)

Compare word by word with the PDF:
- **OCR typos:** lost `ñ`/accents ("tenir" for teñir, "limeno" for limeño), extra or doubled letters ("obrerro"), wrong letters ("cerilios", "Duna" for Puna, "tola" for tolva), merged words ("genegoísta"), table headers glued together ("horashombresporcalculadora").
- **Translation:** the OCR model sometimes translates Spanish to English ("Calculate", "the value of"). The exam is in Spanish.
- **Roman numerals:** "1." for "I.", bars for numerals ("||", "∣V", "∨" for II, IV, V), "Ⅴ-Ⅲ" lookalike glyphs. In ordering questions ("Elija la secuencia correcta…") every choice must read like `II - V - IV - I - III`, exactly as in the PDF.
- **Statements (I, II, III…):** all present, in the PDF's order, one per paragraph, nothing merged or duplicated. Watch for a garbled duplicate next to the real line. Very common: all five statements of an ordering/insertion item run together in one paragraph ("…malignos. II. El tratamiento…") — split them.
- **Leaked text:** a section heading of the *next* part stuck at the end of the stem, the last choice **or the solution** ("PRECISIÓN LÉXICA EN CONTEXTO", "PLAN DE REDACCIÓN", "ANALOGÍAS", "HUMANIDADES", "4.2. Raz. Verbal", "6.2. Química"); a stray line like "G) La Duna…"; running page headers or footers. Check the last question of every section, in both the stem and the solution.
- **Choices:** exactly A–E; every letter has the PDF's text (OCR can **shift** choices — e.g. A's text under E — or **invent** them); choice text left behind in the stem (e.g. the last word of choice D printed alone after the stem); choices **truncated** (last word missing); choices out of order.
- **Blanks in fill-in items:** count the `___` against the number of words each choice supplies; OCR drops blanks (a statement "V." with nothing after it, a sentence with 2 blanks whose choices give 3 connectors).
- **Paragraph splits:** a column or page break can cut a sentence into two paragraphs (the second starts lowercase; OCR may even add a period before the break). Join them. The reverse also happens: one PDF paragraph stored as one paragraph per printed line — join those too.
- **Numbers as printed:** UNI prints decimal commas (`-334,8`, `0,62 V`, `c = 4,18`); OCR often turns them into points in choices and data. Same for thousands spacing (`7 780 900`). Keep the PDF's form.
- **Don't "improve" the PDF:** the builder sometimes adds accents or fixes the official text ("característica" where the PDF has "caracteristica", "fue" for "fué"). Revert to the PDF unless it's clearly OCR damage.
- **Passage/title lines** ("TEXTO", "SOPORTES DE LA ESCRITURA") belong in the stem when the PDF shows them there.

### Pass 2 — Math, notation, figures and layout

- **Notation identical to the PDF:** subscripts/superscripts, fractions, roots, overlines (`\overline{ab}`), vectors, units, degrees, and special operators. Example fixed before: the official doc shows *t inside a circle*; OCR wrote `\bigcirc t`; correct is `\enclose{circle}{t}` (renders in production's MathJax 4.1 and the preview). Spanish trig: `\operatorname{sen}` (not `\sin`); `\arccot` doesn't exist → `\operatorname{arccot}`. Chemistry formulas as upright text, e.g. `$\mathrm{HNO_{3}}$` (don't use `\ce{}`).
- **Interval brackets and delimiters exactly as printed** — they change the answer: `⟨−∞; 0]` vs `⟨−∞; 0⟩`, `[a, b⟩` vs `[a, b]`. Check every choice of interval questions. Use `\langle` / `\rangle`; greatest-integer brackets ⟦ ⟧ as `[\![x]\!]`.
- **Math in prose:** variables, point/segment names and short expressions that the PDF sets in math italics (`$N$`, `$ABC$`, `$BC = a$`, `$(8; 3)$`, `$[0; 2\pi]$`) go inside `$...$`.
- **Units and chemistry upright:** `9{,}81\ \mathrm{m/s^{2}}`, `20\ \mathrm{cm}`, `\mathrm{eV}`, `\mathrm{MgCl_{2}}`, `{}_{20}\mathrm{Ca}`, `\mathrm{H_{2}O}_{(\ell)}`. Decimal commas inside math as `{,}` (`1{,}21C`), otherwise MathJax adds a space after the comma.
- **Nothing lost from formulas:** equation tags the text refers to (`(*)`, `(α)`, `(1)` → `\qquad (1)`), cancellation strokes (`\cancel{m}`), labels over arrows (`\overset{\text{desplaza}}{\overrightarrow{...}}`), the "#" of "# de caras" (`$\#$`), leading arrows/signs of a line.
- **Lookalike glyphs:** `Ⅰ Ⅱ` (Unicode roman numerals) → `I II`; `■` / `∎` bullets → `▪ `; a cancelled *m* read as `\mathfrak{m}`, `\mathcal{H}` or even a CJK character (翱) → `\cancel{m}`; spaced-out letters (`\mathrm{f o t o n}`, `\mathrm{a u m e n t a}`) lose accents and look wrong → `\text{fotón}`.
- **LaTeX must be inside math delimiters:** `A^{T}`, `HNO_{3}`, `2 \times 2`, `10\ m/s`, a `\begin{pmatrix}` outside `$...$` show up raw in Discourse (the preview's MathJax may still render some of them, so don't trust the popup alone — read the source). Wrap them (`$A^{T}$`), and replace a stray `\ ` outside math with a space.
- **Markdown traps the preview hides:** the preview renderer has no lists, but Discourse turns any line starting with `- `, `+ `, `* `, `1. `, `# ` or `> ` into a list item, heading or quote (a solution line "- 1 + 2 = 0" loses its minus sign). Use `▪ ` for bullets (as the PDF shows), put leading signs inside the math (`$-1 + 2 + 1 - 2 = 0$`), and write `$\#$`. Lists of items go one per line inside one paragraph (single `\n`).
- **"Respuesta X" is plain text** on its own last paragraph — not inside a LaTeX array or `\boxed{}`, not wrapped in table pipes (`| Respuesta C |`).
- **Math must not span a blank line:** a `$...$` containing a newline, or blank lines inside `$$...$$`, breaks in Discourse (an OCR'd `\begin{array}` table is the classic case). Make it one `$$ ... $$` on a single line.
- **Split formulas:** one equation broken into several `$...$` pieces across lines (merge into one).
- **Figures:** every figure in the PDF is present (OCR sometimes misses one entirely); attached to the right question (not a neighbour); not cut off (whole drawing, labels included); not duplicated; placed where the PDF has it (before/after the statements). Typical OCR crop damage: a label of the neighbouring figure caught at the edge ("A)", "M"), axis titles cut ("(millones)", "PET: 7 780 900"), figures the PDF shows side by side stored as several stacked images (crop the whole row/grid as one image), a solution figure that includes the boxed "Respuesta X" (recrop without it). Drawings can extend past the column edge (x≈305 pt on these pages): find the real extent with `page.get_drawings()` before cropping. A formula line saved as an image should become LaTeX.
- **Image choices:** each image under the right letter (OCR scrambles label order on 2-column grids; labels may sit beside or under the figures). A choice that is a drawing *plus* text (e.g. a ring structure + ": cicloalqueno") is one image of the whole choice.
- **Tables:** must be markdown pipe tables (`| a | b |` + `|---|---|`), never HTML `<table>` (math inside raw HTML doesn't render in Discourse); cell text identical to the PDF.
- To add or replace a figure, crop it from the PDF at 216 dpi into `PDF_DIR/images_hd/pNNN_manual_p<prueba>q<numero>_<what>.jpg` (NNN = 1-based page), look at it, then store it as a data URL (`'data:image/jpeg;base64,' + base64`) in `figureImages` / `choiceImages` / `solutionFigureImages`, with a matching `[FIG:n]` marker in the text, and update the matching `figureRefs` / `solutionFigureRefs` entry to `images_hd/<file>`. Keep `[FIG:n]` indices contiguous (0..len-1). **Never overwrite an existing `*_manual_*` file** (they may be the user's): make your crop script refuse to write when the file exists.

### Pass 3 — Rendered result, solution and metadata

- **Popup health:** `mathErrors == 0`, `undefinedMacros == 0`, `rawLatex == false`, `brokenImgs == 0`, and the screenshot looks like the PDF (layout, figure size/placement, choices list).
- **Inline math boundaries (Discourse only, the preview hides it):** discourse-math renders an inline `$...$` only when the character just before the opening `$` and just after the closing `$` is whitespace, punctuation or the line edge. `$ {}^{\circ} $C`, `$ 67{,}5 $Kilos`, `$a$$b$` render on the preview but break on Discourse — put the unit inside the math (`{}^{\circ}\mathrm{C}`) or add a space. Run `check_math_boundaries.js` (in the 2026-10-04 scratchpads, `prodpub/` or `r2022/`; copy it into yours) over the whole batch at the end.
- **Literal dollar signs:** an amount printed "$ 2 000 000" must be written `\$ 2 000 000`; an unescaped `$` pairs with the next one and turns the text between into italic math (2021-I P2#1 lost its whole stem that way). `\$` was cooked on local Discourse with the site's own markdown engine: literal "$", no math span. (The popup's raw-LaTeX check then flags the "$"; that hit is expected.)
- **PDFs made in Word lose glyphs in the PDF itself** (2021-I): big parentheses print as "Å … ã", radicals and some operators vanish, ∠ prints as "]". OCR copies the junk (`\mathring{A}`, `\tilde{a}`, `\sqrt[8]{\frac{}{11}}`, numerators lost). Rebuild those formulas from the math and the 220-dpi image, and check the result still gives the key.
- **Same-looking ≠ same symbol:** two different hand-drawn operators must not collapse into one Unicode character (2022-I T1#35: a heart and an upside-down heart both became ♡, making the definition circular) — crop them. An inline determinant (`vmatrix` inside `$...$`) can render without its bars in the preview's MathJax 3: put it on its own `$$...$$` line.
- **Answer key:** `clave` equals the solucionario's "Respuesta X" for that question number. If the solution gives a value instead of a letter, match it to the choices and double-check by solving.
- **Solution:** belongs to *this* question (two-column pages can push the end of one solution into the next), is complete (no missing derivation lines or figures), has the same notation fixes as the stem, and ends with "Respuesta X" matching `clave`.
- **Metadata:** `numero` matches the PDF; `tema` is the right subject and exists in the composer's `TEMAS` list for that university (UNI Prueba 1 follows the section headers; UNI Prueba 2 is decided by content: Aritmética, Álgebra, Geometría, Trigonometría, Álgebra Lineal, Geometría Analítica, Lógica…; UNI Prueba 3 is Física / Química; UNMSM follows its section headers); `subtemas` are valid slugs from `SUB_TEMAS` **listed under that record's own tema** (the classifier has used other temas' slugs, e.g. Aritmética's `logica-y-conjuntos` on Razonamiento Matemático items) and never empty — check all of them with one script against `SUB_TEMAS`; `modalidad`, `tipo_area`, `anio`, `convocatoria` (bare roman numeral) correct. For reading clusters, the passage lives in the root record and each linked question must point to the right root.
- **Title** (popup `<h1>`, built from the stem like the server will): no image or table code, math readable. Duplicates inside the batch get an automatic "— N° x (<universidad> <anio>-<convocatoria>)" suffix; that's expected. Known title-builder traps (fix in the stem's LaTeX, it renders the same): `\\` inside an array becomes "; " → use `\cr` for row breaks in a stem's first line (2022-I T1#33); `**bold**` is not stripped → keep bold out of the first 80 characters or use `$\mathbf{x}$`; `\dfrac` isn't handled ("8/23" shows as "823") → `\frac` in stems; a Greek letter or `\cdot` glued to the next command drops a symbol (`\alpha\hat{i}`, `\cdot\operatorname{sen}`) → add a space after it. Report title bugs you can't fix in data (e.g. `\boxed{6^{2}}` shows "62"; superscripts flattened "x2"; `\frac` with nested braces not converted; `\sum`, `\cap`, `\cup` and "___" blanks dropped). (`\rightarrow`/`\rightleftharpoons` losing their `right` prefix was fixed in server.js on 2026-10-04.)

## Resolving a difference (escalation ladder)

When the batch differs from the PDF and the fix isn't a plain text edit, climb only as far as needed:

1. **Re-OCR the spot.** Send just that crop or page (never the whole PDF) to PaddleOCR-VL and take its text/LaTeX as a candidate. Accept it only if it matches the image.
2. **LaTeX workaround.** PaddleOCR often repeats the same mistake (it read the circled t as `\bigcirc t` again). Write the LaTeX yourself so it *looks like the PDF*. Known good choices:
   - `\enclose{circle}{t}` for a letter or number inside a circle;
   - `\boxed{n}` for a boxed operator;
   - `\operatorname{sen}` (also `arcsen`, `arccot`…) for function names MathJax doesn't define;
   - `\mathrm{HNO_{3}}` for chemistry formulas;
   - `\overline{ab}` for numerals with a bar;
   - `\underline{\text{word}}` for underlined words;
   - markdown pipe tables for tables;
   - `\cancel{...}` for crossed-out terms; `\vdots` for vertical dots; `\underbrace{x}_{y}` / `\overbrace{x}^{y}` for annotated terms;
   - `\overset{\circ}{13}` for "multiple of 13"; `[\![x]\!]` for greatest integer (NOT `\llbracket x \rrbracket`: undefined in Discourse's MathJax 4.1, it shows as red text — re-checked 2026-10-04);
   - `\rightleftarrows` or Unicode `⇌` for equilibrium arrows; `\overset{\text{label}}{\overrightarrow{...}}` for a labelled arrow;
   - `\begin{pmatrix}…\\…\end{pmatrix}`, `aligned`, `array` work inside `$...$` (rows separated by `\\`, never a bare `\ `).

   All of the above were tested in both MathJax versions (2026-10-04). Avoid `\ce{}`, custom macros and HTML. **Test any other unusual command where students will see it:** the preview popup runs MathJax 3.2, Discourse runs MathJax 4.1.

   **Test on LOCAL Discourse, never on production.** Local (`http://localhost:8080`) runs the same Discourse (2026.10.0), the same MathJax (4.1.0) and identical `discourse_math_*` settings as production (compared 2026-10-04), so a local result is the production result. Opening a production question page — even with request blocking — is counted as student traffic: the page load itself adds a topic view, and the shared Playwright MCP profile has Discourse's service worker registered, which lets the metrics beacon slip past `page.route` (on 2026-10-04 this logged 4 fake `pregunta_vista` events on production topic 338). Use this script in a fresh headless browser instead (write it to your scratchpad with the Write tool; it blocks service workers, stubs the beacon and aborts tracking requests even locally):
   ```js
   // node mathjax_probe.js <baseUrl> <topicId with math> <tex> [<tex> ...]
   // Compiles each TeX string with the MathJax that Discourse site actually serves (discourse-math) and
   // prints ok / ERROR / UNDEFINED per formula. Use LOCAL Discourse (http://localhost:8080): it runs the
   // same Discourse + MathJax version as production, so nothing on production is touched.
   // Fresh headless context (never the shared Playwright MCP profile), service workers blocked, the
   // metrics beacon stubbed and tracking requests aborted.
   const { chromium } = require('C:/Users/smart/AppData/Local/npm-cache/_npx/9833c18b2d85bc59/node_modules/playwright-core');
   const [, , BASE, topicId, ...texs] = process.argv;
   (async () => {
     // Open the canonical /t/<slug>/<id> URL directly: local Discourse redirects /t/<id> to a port-less
     // http://localhost/... address that a browser on Windows cannot reach.
     const t = await (await fetch(`${BASE}/t/${topicId}.json`, { headers: { Accept: 'application/json' } })).json();
     const browser = await chromium.launch({ executablePath: 'C:/Users/smart/AppData/Local/ms-playwright/chromium_headless_shell-1228/chrome-headless-shell-win64/chrome-headless-shell.exe' });
     const ctx = await browser.newContext({ serviceWorkers: 'block' });
     await ctx.addInitScript(() => {
       navigator.sendBeacon = () => true;
       const f = window.fetch;
       window.fetch = (u, o) => (String(u).includes('/preuni/evento') ? Promise.resolve(new Response('{}')) : f(u, o));
     });
     await ctx.route('**/*', r => {
       if (/\/preuni\/evento|\/topics\/timings|\/message-bus\//.test(r.request().url())) return r.abort();
       const h = { ...r.request().headers() };
       delete h['discourse-track-view']; delete h['discourse-track-view-topic-id'];
       return r.continue({ headers: h });
     });
     const page = await ctx.newPage();
     await page.goto(`${BASE}/t/${t.slug}/${topicId}`, { waitUntil: 'domcontentloaded' });
     await page.waitForFunction(() => window.MathJax && window.MathJax.tex2chtmlPromise, null, { timeout: 40000 });
     console.log(`MathJax ${await page.evaluate(() => MathJax.version)} at ${BASE}`);
     for (const tex of texs) {
       const res = await page.evaluate(async x => {
         try {
           const n = await MathJax.tex2chtmlPromise(x);
           const e = n.querySelector('mjx-merror');
           if (e) return 'ERROR ' + (e.getAttribute('data-mjx-error') || e.textContent);
           return n.querySelector('[style*="red"], [mathcolor="red"]') ? 'UNDEFINED (shown in red)' : 'ok';
         } catch (err) { return 'ERROR ' + err; }
       }, tex);
       console.log(`${res.padEnd(12)} ${tex}`);
     }
     await browser.close();
   })().catch(e => { console.error('FATAL', e.message); process.exit(1); });
   ```
   Run it with a LOCAL topic that has math (any published 2024-II P2 question; e.g. 690 = P2#24) and the TeX to test, one argument each: `node mathjax_probe.js http://localhost:8080 690 '\enclose{circle}{t}' '\cancel{x}'`. Each line prints `ok`, `ERROR <message>` or `UNDEFINED (shown in red)`. Treat UNDEFINED as a failure: an unknown command raises no MathJax error, it just appears as red text (this is how `\llbracket` slipped through as "verified"). If local Discourse is down, start it (see the local dev notes); do not fall back to production.
3. **Image (last resort).** If no LaTeX renders it faithfully (a hand-drawn symbol, special layout, an operator table, a diagram mixed with text), crop exactly that part from the PDF at 216 dpi and insert it as an image:
   - in a stem or solution, as a `[FIG:n]` block where the content sits (images are block-level, so crop the whole line or formula, not one symbol mid-sentence), and remove the text it replaces so nothing appears twice;
   - in a choice, as that letter's `choiceImages` entry, with the choice text emptied.

   Prefer an image over a "close enough" rendering that changes the meaning or notation.

Record which rung fixed each difference in the report; recurring rung-2 patterns become builder rules for the next batch.

## Fix → verify loop

1. Write the fix as a script (exact old → new, asserted once), run it, re-read the record.
2. Reload the preview, re-render the popup, re-run the health check and look at the screenshot against the PDF crop again.
3. If something can't be fixed confidently, add a clear item to `needsReview` (e.g. `"review:figure_unclear"`) instead of guessing, so it shows as "Por revisar" in the preview.

## Working in chunks

- Work in chunks of about 10 questions. After each chunk, append to a progress log in your scratchpad (`review_progress.md`): ids done, and a table `id | pass | problem (PDF vs batch) | fix | rung (text edit / re-OCR / LaTeX workaround / image) | verified`, plus the ids that needed no change and the open items. If the session is interrupted, resume from the log (the scratchpad survives; re-check that the batch file still holds your last edits).
- When a pattern shows up twice, scan the whole RANGE for it at once (leaked headings, list triggers, statement merges, decimal points, cross-tema subtemas) instead of waiting to meet it question by question.

## Final sweep (whole RANGE, after the last chunk)

1. Popup health for every record in RANGE (`mathErrors == 0`, `undefinedMacros == 0`, `rawLatex == false`, `brokenImgs == 0`) and read every `<h1>` title; `check_math_boundaries.js` reports 0 offending spans.
2. `clave` == PDF "Respuesta X" for every record, and every solution ends with "Respuesta <clave>".
3. A lint script: no `$$...$$` containing a blank line, no inline `$...$` spanning a newline, even `$` count, no LaTeX outside math, no HTML `<table>`, no line starting with a Markdown list/heading trigger, no lookalike glyphs (Ⅰ Ⅱ ■ ∎), no leaked headings (CAPÍTULO, "N.N. Section", PRUEBA), `[FIG:n]` contiguous and matching the image lists, choices exactly A–E and each either text or image (not both, not neither), subtemas valid for the record's tema.

## The report (format the user asked to keep)

Lead with the outcome, keep it scannable, and keep the long per-question table in `review_progress.md` (give its path). In this order:

1. **One outcome paragraph:** batch and RANGE, how many records reviewed, how many fields fixed (count the lines in your edit log), that nothing was published, committed or pushed, the answer-key result vs the PDF, and the final popup health ("0 math errors, 0 undefined macros, 0 raw LaTeX, 0 broken images, 0 Discourse math-boundary offenders").
2. **"Fixes that changed the meaning"** — a table `id | pass | problem (PDF vs batch) | fix | rung` with only the fixes a student would have been misled by (wrong brackets, truncated or shifted choices, lost blanks, wrong words, figures cut or carrying the answer). Point to `review_progress.md` for the full table of every fix.
3. **Questions fixed with the last resort (rung 3: text replaced by a PDF crop)** — always include this list, as a table `id | where (stem / choice / solution) | what the PDF shows | why LaTeX wasn't enough | crop file`. Then, separately, list the questions that only got a **better crop of a figure that was already an image** (one line each, with what was wrong), and any case that went the other way (an image replaced by LaTeX). Don't mix the three.
4. **Counts by error type** (approximate number of records affected), most frequent first, including "answer keys: N wrong".
5. **Builder improvements for the next batch** (recurring patterns) and any **title-builder / preview bugs** found that you worked around in the data.
6. **Open items for the user:** official-PDF typos kept, taxonomy decisions, `needsReview` flags you added, anything you did by mistake and how you repaired it.
7. **Housekeeping:** where the backup is, the new `images_hd/*_manual_*` files, tools that were unavailable (e.g. PaddleOCR MCP not exposed).
8. A one-line offer to publish the full report as a page if another session should have it.

If the batch was already published, add the list of published questions whose batch record changed, so the upload session can update the live topics.
