// Guest mode: answers given without an account live only in this browser
// (localStorage), never in the public statistics. When the visitor signs up
// or logs in, initializers/preuni-invitado.js imports them into the account
// (POST /preuni/importar) and clears this store. Every access is guarded --
// private browsing or blocked storage must never break answering.

const CLAVE = "preuni_invitado_respuestas";
const MAXIMO = 500;

function leer() {
  try {
    const datos = JSON.parse(window.localStorage.getItem(CLAVE) || "{}");
    return datos && typeof datos === "object" ? datos : {};
  } catch {
    return {};
  }
}

function escribir(datos) {
  try {
    window.localStorage.setItem(CLAVE, JSON.stringify(datos));
  } catch {
    // storage full or blocked: the answer still shows, it just isn't kept
  }
}

export function guardarRespuestaInvitado(postId, respuesta, segundos) {
  if (!postId) return;
  const datos = leer();
  if (!datos[postId] && Object.keys(datos).length >= MAXIMO) return;
  datos[postId] = { r: respuesta, t: segundos, en: new Date().toISOString() };
  escribir(datos);
}

export function respuestaInvitado(postId) {
  return postId ? leer()[postId] || null : null;
}

export function respuestasInvitado() {
  return leer();
}

export function contarRespuestasInvitado() {
  return Object.keys(leer()).length;
}

export function limpiarRespuestasInvitado() {
  try {
    window.localStorage.removeItem(CLAVE);
  } catch {
    // nothing to clear
  }
}
