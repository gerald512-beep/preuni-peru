// One-off migration: convert inline "![](images/xxx.jpg)" markdown in body
// and solutionBody into [FIG:N] markers (matching what bulk_seed.js now does
// at parse time), rebuilding figureImages/solutionFigureImages to stay
// index-aligned with the markers. Skips already-manually-fixed records.
// Usage: node migrate_figure_markers.js <mineru_markdown_dir>

const fs = require('fs');
const path = require('path');

const [,, mdDir] = process.argv;
if (!mdDir) { console.error('Usage: node migrate_figure_markers.js <mineru_markdown_dir>'); process.exit(1); }
const imagesDir = path.join(mdDir, 'images');

const MIME_BY_EXT = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png' };
function resolveFigureToDataUrl(ref) {
  const filePath = path.join(imagesDir, path.basename(ref));
  if (!fs.existsSync(filePath)) return null;
  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME_BY_EXT[ext] || 'image/jpeg';
  return `data:${mime};base64,${fs.readFileSync(filePath).toString('base64')}`;
}

function insertFigureMarkers(text) {
  const refs = [];
  const markedText = (text || '').replace(/!\[.*?\]\((images\/[^)]+)\)/g, (_, ref) => {
    const idx = refs.length;
    refs.push(ref);
    return `[FIG:${idx}]`;
  });
  return { markedText, refs };
}

const jsonPath = path.join(__dirname, 'bulk_review.json');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

let migrated = 0, skipped = 0;
for (const r of data) {
  if (r.manuallyFixed) { skipped++; continue; }

  let changed = false;

  if (r.body && /!\[.*?\]\(images\//.test(r.body)) {
    const { markedText, refs } = insertFigureMarkers(r.body);
    r.body = markedText;
    r.figureRefs = refs;
    r.figureImages = refs.map(resolveFigureToDataUrl).filter(Boolean);
    changed = true;
  }

  if (r.solutionBody && /!\[.*?\]\(images\//.test(r.solutionBody)) {
    const { markedText, refs } = insertFigureMarkers(r.solutionBody);
    r.solutionBody = markedText;
    r.solutionFigureRefs = refs;
    r.solutionFigureImages = refs.map(resolveFigureToDataUrl).filter(Boolean);
    changed = true;
  }

  if (changed) migrated++;
}

fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`Migrated ${migrated} records with inline figures. Skipped ${skipped} already manually-fixed records.`);
