// Manual classification for UNI 2019-2's pending-tema questions (Prueba 2
// Matemática + Traslado Externo's Matemática Básica I/II). These are read
// and assigned by direct content review, not a general-purpose classifier —
// a future solucionario would go through Claude classification instead.
// Patches bulk_review.json in place.

const fs = require('fs');
const path = require('path');

const CLASSIFICATIONS = {
  // Prueba 2 — MATEMÁTICA
  'p2-MATEMÁTICA-01': ['Probabilidad y Estadística', ['esperanza-matematica']],
  'p2-MATEMÁTICA-02': ['Aritmética', ['bases-numericas']],
  'p2-MATEMÁTICA-03': ['Aritmética', ['bases-numericas']],
  'p2-MATEMÁTICA-04': ['Álgebra', ['divisibilidad-algebraica']],
  'p2-MATEMÁTICA-05': ['Aritmética', ['mcd-mcm']],
  'p2-MATEMÁTICA-06': ['Aritmética', ['fracciones']],
  'p2-MATEMÁTICA-07': ['Aritmética', ['cuadrados-perfectos']],
  'p2-MATEMÁTICA-08': ['Álgebra', ['funciones-polinomiales']],
  'p2-MATEMÁTICA-09': ['Álgebra Lineal', ['matrices-determinantes']],
  'p2-MATEMÁTICA-10': ['Álgebra', ['programacion-lineal']],
  'p2-MATEMÁTICA-11': ['Álgebra', ['sistemas-ecuaciones']],
  'p2-MATEMÁTICA-12': ['Álgebra Lineal', ['sistemas-lineales']],
  'p2-MATEMÁTICA-13': ['Álgebra', ['optimizacion-cuadratica']],
  'p2-MATEMÁTICA-14': ['Álgebra', ['ecuaciones']],
  'p2-MATEMÁTICA-15': ['Álgebra', ['inecuaciones']],
  'p2-MATEMÁTICA-16': ['Álgebra', ['sucesiones-convergencia']],
  'p2-MATEMÁTICA-17': ['Lógica', ['logica-proposicional']],
  'p2-MATEMÁTICA-18': ['Álgebra', ['funciones-logaritmicas']],
  'p2-MATEMÁTICA-19': ['Álgebra', ['funciones']],
  'p2-MATEMÁTICA-20': ['Álgebra', ['numeros-complejos']],
  'p2-MATEMÁTICA-21': ['Geometría', ['triangulos']],
  'p2-MATEMÁTICA-22': ['Geometría', ['triangulos']],
  'p2-MATEMÁTICA-23': ['Geometría', ['cuadrilateros']],
  'p2-MATEMÁTICA-24': ['Geometría', ['circunferencia', 'poligonos']],
  'p2-MATEMÁTICA-25': ['Geometría', ['circunferencia']],
  'p2-MATEMÁTICA-26': ['Geometría', ['circunferencia', 'cuadrilateros']],
  'p2-MATEMÁTICA-27': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-28': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-29': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-30': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-31': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-32': ['Geometría', ['geometria-del-espacio']],
  'p2-MATEMÁTICA-33': ['Trigonometría', ['funciones-trigonometricas-inversas']],
  'p2-MATEMÁTICA-34': ['Trigonometría', ['ecuaciones-trigonometricas']],
  'p2-MATEMÁTICA-35': ['Trigonometría', ['identidades-trigonometricas', 'triangulo-oblicuangulo']],
  'p2-MATEMÁTICA-36': ['Trigonometría', ['circunferencia-trigonometrica']],
  'p2-MATEMÁTICA-37': ['Trigonometría', ['circunferencia-trigonometrica']],
  'p2-MATEMÁTICA-38': ['Trigonometría', ['funciones-trigonometricas']],
  'p2-MATEMÁTICA-39': ['Geometría Analítica', ['conicas']],
  'p2-MATEMÁTICA-40': ['Geometría', ['optimizacion-area']],

  // Traslado — MATEMÁTICA BÁSICA I (coordinate geometry throughout)
  'ptraslado-MATEMÁTICA_BÁSICA_I-01': ['Geometría Analítica', ['rectas']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-02': ['Geometría Analítica', ['rectas', 'bisectriz']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-03': ['Geometría Analítica', ['rectas-paralelas']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-04': ['Geometría Analítica', ['rectas']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-05': ['Geometría Analítica', ['lugares-geometricos']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-06': ['Geometría Analítica', ['circunferencia']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-07': ['Geometría Analítica', ['circunferencia']],
  'ptraslado-MATEMÁTICA_BÁSICA_I-08': ['Geometría Analítica', ['conicas']], // hipérbola
  'ptraslado-MATEMÁTICA_BÁSICA_I-09': ['Geometría Analítica', ['conicas']], // parábola
  'ptraslado-MATEMÁTICA_BÁSICA_I-10': ['Geometría Analítica', ['conicas']], // elipse

  // Traslado — MATEMÁTICA BÁSICA II (linear algebra throughout)
  'ptraslado-MATEMÁTICA_BÁSICA_II-11': ['Álgebra Lineal', ['matrices-rango']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-12': ['Álgebra Lineal', ['matriz-inversa']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-13': ['Álgebra Lineal', ['planos-angulo']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-15': ['Álgebra Lineal', ['espacios-vectoriales']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-16': ['Álgebra Lineal', ['planos-proyeccion']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-17': ['Álgebra Lineal', ['valores-propios']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-18': ['Álgebra Lineal', ['rectas-espacio']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-19': ['Álgebra Lineal', ['espacios-vectoriales']],
  'ptraslado-MATEMÁTICA_BÁSICA_II-20': ['Álgebra Lineal', ['matrices-propiedades']],
};

const jsonPath = path.join(__dirname, 'bulk_review.json');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

let applied = 0, stillPending = 0;
for (const r of data) {
  if (!r.pendingClassification) continue;
  const c = CLASSIFICATIONS[r.id];
  if (c) {
    r.tema = c[0];
    r.subtemas = c[1];
    r.pendingClassification = false;
    r.classificationMethod = 'manual_review';
    applied++;
  } else {
    stillPending++;
  }
}

fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`Applied ${applied} classifications. Still pending: ${stillPending}.`);
