import { withPluginApi } from "discourse/lib/plugin-api";

// Site analytics (Umami Cloud, cookieless): page views, referrers, devices,
// countries, bounce rate -- what the first-party log (lib/preuni-eventos.js)
// can't see, since that log starts only when someone opens a question.
// Our own events are mirrored there too (registrarEvento -> umami.track).
// Loaded from here rather than a <script> tag in the page head: the site's
// CSP is nonce + strict-dynamic, so a script added by our bundle is trusted.
const UMAMI_SRC = "https://cloud.umami.is/script.js";
const UMAMI_WEBSITE_ID = "89614f90-0768-4e0f-930d-d8826a8d6832";
// Umami only sends from this host (data-domains), so local dev sends nothing.
const DOMINIO = "preuni.voluntaria.pe";
// Umami's own per-browser opt-out. Set for good once a staff/test account is
// seen in a browser -- same rule as the metrics queries, which drop every
// browser ever used by such an account, even when logged out later.
const OPT_OUT = "umami.disabled";

// Discourse rewrites the URL while you scroll a topic (/t/slug/123/7), and
// Umami counts every URL change as a page view. One topic = one view.
let ultimaVista = null;
function antesDeEnviar(tipo, payload) {
  if (payload?.name) {
    return payload; // custom event, not a page view
  }
  try {
    const url = new URL(payload.url);
    url.pathname = url.pathname.replace(/^(\/t\/[^/]+\/\d+)\/\d+\/?$/, "$1");
    const normalizada = url.toString();
    if (normalizada === ultimaVista) {
      return false;
    }
    ultimaVista = normalizada;
    return { ...payload, url: normalizada };
  } catch {
    return payload;
  }
}

function excluido() {
  try {
    return !!window.localStorage.getItem(OPT_OUT);
  } catch {
    return false;
  }
}

export default {
  name: "preuni-umami",

  initialize() {
    withPluginApi("1.0", (api) => {
      if (api.getCurrentUser()?.preuni_sin_analitica) {
        try {
          window.localStorage.setItem(OPT_OUT, "1");
        } catch {
          // private mode: the script still isn't loaded for this session
        }
        return;
      }
      if (excluido() || document.getElementById("preuni-umami")) {
        return;
      }
      window.preuniUmamiAntesDeEnviar = antesDeEnviar;
      const s = document.createElement("script");
      s.id = "preuni-umami";
      s.defer = true;
      s.src = UMAMI_SRC;
      s.dataset.websiteId = UMAMI_WEBSITE_ID;
      s.dataset.domains = DOMINIO;
      s.dataset.excludeSearch = "true";
      s.dataset.beforeSend = "preuniUmamiAntesDeEnviar";
      document.head.appendChild(s);
    });
  },
};
