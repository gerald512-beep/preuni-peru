// Fire-and-forget click/view logging (POST /preuni/evento). sendBeacon
// survives the navigation that login links and result clicks trigger; a
// dropped event must never break the UI, so every failure is swallowed.

const CLAVE = "preuni_visitante_id";
let visitanteEnMemoria = null;

function nuevoId() {
  if (window.crypto?.randomUUID) {
    return window.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

// Stable per browser, and kept after login so a visitor's anonymous events
// join to the account they create.
function visitanteId() {
  try {
    let id = window.localStorage.getItem(CLAVE);
    if (!id) {
      id = nuevoId();
      window.localStorage.setItem(CLAVE, id);
    }
    return id;
  } catch {
    visitanteEnMemoria ??= nuevoId();
    return visitanteEnMemoria;
  }
}

// Same event in Umami (initializers/preuni-umami.js), scalar data only.
// window.umami is absent for staff/test browsers and until the script loads.
function enUmami(evento, datos) {
  try {
    const props = {};
    Object.entries(datos ?? {}).forEach(([k, v]) => {
      if (["string", "number", "boolean"].includes(typeof v)) {
        props[k] = v;
      }
    });
    window.umami?.track(evento, props);
  } catch {
    // analytics must never break the page
  }
}

export function registrarEvento(evento, { topicId, postId, datos } = {}) {
  enUmami(evento, datos);
  try {
    const cuerpo = JSON.stringify({
      evento,
      visitante_id: visitanteId(),
      topic_id: topicId ?? null,
      post_id: postId ?? null,
      datos: datos ?? {},
    });
    const blob = new Blob([cuerpo], { type: "application/json" });
    if (navigator.sendBeacon?.("/preuni/evento", blob)) {
      return;
    }
    fetch("/preuni/evento", {
      method: "POST",
      body: cuerpo,
      headers: { "Content-Type": "application/json" },
      keepalive: true,
      credentials: "same-origin",
    }).catch(() => {});
  } catch {
    // analytics must never break the page
  }
}
