import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { registrarEvento } from "../lib/preuni-eventos";
import {
  limpiarRespuestasInvitado,
  respuestasInvitado,
} from "../lib/preuni-invitado";

// Guest mode, last step: answers given in this browser before signing up or
// logging in move into the account (POST /preuni/importar), so nobody loses
// what they practised as a guest. Runs once per browser -- the store is
// cleared after a successful import; a failed one is retried on next boot.
async function importarRespuestas(owner, user) {
  const guardadas = respuestasInvitado();
  const respuestas = Object.entries(guardadas).map(([postId, r]) => ({
    post_id: Number(postId),
    respuesta: r.r,
    tiempo_segundos: r.t ?? null,
    respondida_en: r.en,
  }));
  if (!user || !respuestas.length) {
    return;
  }
  try {
    const data = await ajax("/preuni/importar", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify({ respuestas }),
    });
    limpiarRespuestasInvitado();
    const n = data.importadas || 0;
    registrarEvento("respuestas_importadas", { datos: { n, enviadas: respuestas.length } });
    if (n > 0) {
      owner.lookup("service:toasts")?.success({
        duration: 5000,
        data: {
          message:
            n === 1
              ? "Guardamos en tu cuenta la respuesta que diste como invitado."
              : `Guardamos en tu cuenta las ${n} respuestas que diste como invitado.`,
        },
      });
    }
  } catch {
    // keep them for the next visit
  }
}

export default {
  name: "preuni-invitado",

  initialize(owner) {
    withPluginApi("1.0", (api) => {
      importarRespuestas(owner, api.getCurrentUser());
    });
  },
};
