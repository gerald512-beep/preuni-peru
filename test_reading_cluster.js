// Proof-of-concept test for Option A: one topic, root = passage + Q1, then
// Q2/Q3 as replies each carrying their own clave/choices via preuni_post_type
// = "pregunta_adicional". Bypasses server.js/the composer entirely -- this is
// just to validate the new plugin.rb + widget mechanism end-to-end before any
// UI is built for it. Based on a real UNMSM reading-comprehension example
// (TEXTO 1 + Preguntas 11-13) the user shared as source material.
require('dotenv').config();

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME, 'Content-Type': 'application/json' };
const UNMSM_RAZ_VERBAL_CATEGORY = 12;

const PASAJE = `**TEXTO 1**

**¿Cómo ingresaron medicamentos inseguros desde la India?**

Entre 2019 y 2025, el Ministerio de Salud adquirió 19 lotes defectuosos de cuatro medicamentos oncológicos esenciales -cisplatino, ifosfamida, ciclofosfamida y doxorrubicina-, usados en quimioterapias para tratar distintos tipos de cáncer. Algunos llegaron con contaminación bacteriana. Otros contenían partículas visibles, como pelusas o fragmentos de vidrio. En un caso, la concentración era menor a la declarada; es decir, la dosis no alcanzaba para producir el efecto terapéutico esperado.

Los 5 laboratorios que fabricaron los 19 lotes con fallas no tenían una certificación peruana vigente de sus plantas. En su lugar, presentaron documentos emitidos en su país de origen. DIGEMID no ha logrado inspeccionar a tiempo a todas las plantas extranjeras que fabrican medicamentos para el Perú. Ante ese cuello de botella, autorizó el ingreso de productos con certificados del país de origen, sin inspección directa. Esa excepción rige desde 2013.

Como resultado, más de 140 000 frascos, cuya inversión no se pudo traducir en quimioterapias aplicables, fueron descartados. Cada frasco destruido fue una sesión que no llegó a tiempo a un paciente. Retirar medicamentos defectuosos es indispensable, pero cuando no hay reemplazo inmediato, el hospital se queda sin alternativa.

Los lotes comprometidos pertenecían a cinco laboratorios de la India: Beta Drugs, United Biotech, Kwality Pharmaceuticals, Vee Excel Drugs & Pharmaceuticals y Naprod Life Sciences. Al menos tres de los laboratorios con plantas en la India que se identificaron ya tenían antecedentes de haber vendido a algunos países de la región otros fármacos con fallas de calidad. El historial de Naprod Life Sciences incluye la fabricación de un lote de metotrexato contaminado con bacterias que causó la muerte de cuatro niños en Colombia en 2020. Pese a este grave episodio, el Estado peruano continuó comprándole, incluso el mismo fármaco vinculado a esas muertes.

*Adaptado de: Martínez, J., Torres, F., Romero, A., Eccles, P., Milijovejevic, A. (2026, 12 de febrero). El Estado compró más de 140 000 medicamentos oncológicos defectuosos que acabaron en la basura. Salud con Lupa.*`;

const P11 = `${PASAJE}

**Pregunta 11**

La frase "CADA FRASCO DESTRUIDO FUE UNA SESIÓN QUE NO LLEGÓ A TIEMPO A UN PACIENTE" tiene la intención de`;
const P11_CHOICES = {
  A: 'exacerbar la indignación del lector.',
  B: 'evidenciar el daño ocasionado al paciente.',
  C: 'patentizar la tristeza de los familiares.',
  D: 'solivianter a la opinión pública.',
  E: 'alterar las relaciones entre India y Perú.',
};
const R11 = `**Definición contextual**

La respuesta está en el primer párrafo del cuarto bloque del texto, que nos remite al daño ocasionado al paciente al no poder usarse los 140 000 frascos destruidos.

**Rpta.: evidenciar el daño ocasionado al paciente.**`;

const P12 = `**Pregunta 12**

Según el texto, las razones por las cuales ingresaron medicamentos defectuosos de la India al Perú fueron las siguientes: haber ___ y haber ___, respectivamente.`;
const P12_CHOICES = {
  A: 'imitado la situación del sistema de salud de Colombia — elevado los estándares peruanos relativos a las importaciones médicas.',
  B: 'investigado su origen a partir de diversas fuentes de noticias — auditado los procesos de distribución de las cadenas peruanas.',
  C: 'ignorado los antecedentes de fallas de calidad de los laboratorios — autorizado la adquisición de productos sin inspección directa.',
  D: 'procurado no desabastecer medicinas a los hospitales — apostado por un aumento en la producción de tres medicinas paliativas.',
  E: 'priorizado la compra inmediata de productos antes que su calidad — encargado a CENARES la licitación de diversas compras.',
};
const R12 = `**Afirmaciones expuestas**

En el texto se habla de la inseguridad de los productos llegados de la India, y de que DIGEMID no tiene certificación peruana vigente de sus plantas, además de haber autorizado el ingreso de esos productos sin inspección directa pese a los antecedentes de fallas de calidad de los laboratorios.

**Rpta.: ignorado los antecedentes de fallas de calidad de los laboratorios — autorizado la adquisición de productos sin inspección directa.**`;

const P13 = `**Pregunta 13**

Sobre la base de la información del texto, si DIGEMID hubiera llevado a cabo la inspección de los medicamentos a tiempo, habría`;
const P13_CHOICES = {
  A: 'ganado un reconocimiento de alcance nacional por su eficacia.',
  B: 'conseguido contribuir con la industria de fármacos oncológicos.',
  C: 'logrado certificar los fármacos bajo los estándares nacionales.',
  D: 'establecido un convenio de cooperación médica con la India.',
  E: 'elevado su capacidad de auditar la fabricación de otros productos.',
};
const R13 = `**Extrapolación**

DIGEMID no ha logrado inspeccionar a tiempo todas las plantas extranjeras que fabrican medicamentos para el Perú, por eso autorizó el ingreso de productos sin inspección directa. Por lo tanto, si DIGEMID hubiera llevado a cabo la inspección de manera correcta y directa, también hubiera logrado certificar los fármacos bajo los estándares nacionales.

**Rpta.: logrado certificar los fármacos bajo los estándares nacionales.**`;

function buildRaw(body, choices) {
  let raw = body.trim() + '\n\n';
  ['A', 'B', 'C', 'D', 'E'].forEach(l => { raw += `**(${l})** ${choices[l]}\n`; });
  return raw;
}

async function post(body) {
  const res = await fetch(`${DISCOURSE_URL}/posts.json`, { method: 'POST', headers, body: JSON.stringify(body) });
  const data = await res.json();
  if (!res.ok) throw new Error('Post failed: ' + JSON.stringify(data));
  return data;
}

(async () => {
  // Root: passage + Q11
  const root = await post({
    title: '¿Cómo ingresaron medicamentos inseguros desde la India? (TEXTO 1)',
    raw: buildRaw(P11, P11_CHOICES),
    category: UNMSM_RAZ_VERBAL_CATEGORY,
    tags: ['N°11', 'lectura-medicamentos-india'],
    topic_custom_fields: {
      preuni_clave: 'B',
      preuni_convocatoria: 'test-reading-cluster',
      preuni_numero: '11',
      preuni_universidad: 'UNMSM',
      preuni_tema: 'Razonamiento Verbal',
      preuni_tipo_origen: 'Universidad',
    },
  });
  const topicId = root.topic_id;
  console.log('Root topic created:', topicId, `${DISCOURSE_URL}/t/${topicId}`);

  await post({ topic_id: topicId, raw: R11, preuni_post_type: 'solucion' });
  console.log('R11 posted');

  await post({
    topic_id: topicId,
    raw: buildRaw(P12, P12_CHOICES),
    preuni_post_type: 'pregunta_adicional',
    preuni_clave: 'C',
    preuni_numero: '12',
  });
  console.log('P12 posted');

  await post({ topic_id: topicId, raw: R12, preuni_post_type: 'solucion' });
  console.log('R12 posted');

  await post({
    topic_id: topicId,
    raw: buildRaw(P13, P13_CHOICES),
    preuni_post_type: 'pregunta_adicional',
    preuni_clave: 'C',
    preuni_numero: '13',
  });
  console.log('P13 posted');

  await post({ topic_id: topicId, raw: R13, preuni_post_type: 'solucion' });
  console.log('R13 posted');

  console.log('\nDone:', `${DISCOURSE_URL}/t/${topicId}`);
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
