// One-off migration: split raw "![](images/xxx.jpg)" choice text into proper
// choiceImages entries, without re-running the full parser (which would
// overwrite any records already fixed by hand via the composer).
// Usage: node migrate_choice_images.js <mineru_markdown_dir>

const fs = require('fs');
const path = require('path');

const [,, mdDir] = process.argv;
if (!mdDir) { console.error('Usage: node migrate_choice_images.js <mineru_markdown_dir>'); process.exit(1); }
const imagesDir = path.join(mdDir, 'images');

const MIME_BY_EXT = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png' };
function resolveFigureToDataUrl(ref) {
  const filePath = path.join(imagesDir, path.basename(ref));
  if (!fs.existsSync(filePath)) return null;
  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME_BY_EXT[ext] || 'image/jpeg';
  return `data:${mime};base64,${fs.readFileSync(filePath).toString('base64')}`;
}

const CHOICE_IMAGE_RE = /^!\[.*?\]\((images\/[^)]+)\)$/;
const jsonPath = path.join(__dirname, 'bulk_review.json');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

let migrated = 0, skipped = 0;
for (const r of data) {
  if (r.manuallyFixed) { skipped++; continue; } // don't touch hand-fixed records
  if (!r.choiceImages) r.choiceImages = {};

  let changed = false;
  for (const l of ['A','B','C','D','E']) {
    const val = (r.choices[l] || '').trim();
    const m = val.match(CHOICE_IMAGE_RE);
    if (!m) continue;
    const dataUrl = resolveFigureToDataUrl(m[1]);
    if (!dataUrl) continue;
    r.choiceImages[l] = dataUrl;
    r.choices[l] = '';
    changed = true;
  }

  if (changed) {
    // Re-validate: a choice with an image now counts as present
    const missing = ['A','B','C','D','E'].filter(l => !r.choices[l]?.trim() && !r.choiceImages[l]);
    r.needsReview = r.needsReview.filter(f => !f.startsWith('missing_choices:'));
    if (missing.length) r.needsReview.push(`missing_choices:${missing.join(',')}`);
    migrated++;
  }
}

fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`Migrated ${migrated} records with choice images. Skipped ${skipped} already manually-fixed records.`);
