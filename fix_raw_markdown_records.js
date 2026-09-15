// Fixes 4 manually-fixed records whose body/solutionBody still had raw
// "![](images/xxx.jpg)" markdown instead of [FIG:N] markers (migrate_figure_markers.js
// skipped manuallyFixed records on purpose, but these 4 needed it anyway).
// The image data itself was already correctly resolved into figureImages/
// solutionFigureImages -- this only fixes the TEXT to reference it properly.
const fs = require('fs');

function insertMarkers(text) {
  let i = -1;
  return text.replace(/!\[.*?\]\(images\/[^)]+\)/g, () => {
    i++;
    return `[FIG:${i}]`;
  });
}

const path = 'bulk_review.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

const BODY_FIX = ['p1-RAZONAMIENTO_MATEMÁTICO-29'];
const SOLUTION_FIX = ['p2-MATEMÁTICA-18', 'p2-MATEMÁTICA-20', 'p2-MATEMÁTICA-28'];

BODY_FIX.forEach(id => {
  const r = data.find(x => x.id === id);
  const before = r.body;
  r.body = insertMarkers(r.body);
  console.log(id, 'body fixed:', before !== r.body);
});

SOLUTION_FIX.forEach(id => {
  const r = data.find(x => x.id === id);
  const before = r.solutionBody;
  r.solutionBody = insertMarkers(r.solutionBody);
  console.log(id, 'solutionBody fixed:', before !== r.solutionBody);
});

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('Saved.');
