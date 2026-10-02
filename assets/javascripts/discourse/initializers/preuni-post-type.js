import { withPluginApi } from "discourse/lib/plugin-api";

const CSS = `
.preuni-type-selector{display:flex;align-items:center;gap:8px;padding:6px 0 2px}
.preuni-type-label{font-size:12px;color:#888}
.preuni-type-btn{
  padding:3px 14px;border-radius:20px;border:1.5px solid #ccc;
  background:#f8f8f8;font-size:12px;cursor:pointer;color:#555;
  transition:all .15s;font-weight:500;line-height:1.6
}
.preuni-type-btn.solucion.active{background:#d4edda;border-color:#28a745;color:#155724;font-weight:700}
.preuni-type-btn.comentario.active{background:#e2e3e5;border-color:#6c757d;color:#383d41;font-weight:700}
.preuni-type-btn:not(.active):hover{border-color:#999}
.topic-post.preuni-solucion .topic-body{border-left:3px solid #28a745;padding-left:10px}
.preuni-solucion-badge{
  display:inline-flex;align-items:center;gap:4px;
  padding:2px 10px;border-radius:4px;font-size:11px;font-weight:700;
  background:#d4edda;color:#155724;border:1px solid #c3e6cb;margin-top:2px
}
.preuni-universitario-badge{
  display:inline-flex;align-items:center;
  padding:2px 8px;border-radius:3px;font-size:11px;font-weight:700;
  background:#fff3cd;color:#856404;border:1px solid #ffc107;margin-left:6px
}
.preuni-egresado-badge{
  display:inline-flex;align-items:center;
  padding:2px 8px;border-radius:3px;font-size:11px;font-weight:700;
  background:#cce5ff;color:#004085;border:1px solid #b8daff;margin-left:6px
}
body:not(.preuni-hilo-abierto) .topic-post.preuni-hilo-respuesta{display:none}
.preuni-hilo-btn{margin-top:8px}
.preuni-moderador-badge{
  display:inline-flex;align-items:center;
  padding:2px 8px;border-radius:3px;font-size:11px;font-weight:700;
  background:#e2d9f3;color:#4a235a;border:1px solid #c9b8e8;margin-left:6px
}
`;

export default {
  name: "preuni-post-type",
  initialize() {
    if (!document.getElementById("preuni-type-css")) {
      const s = document.createElement("style");
      s.id = "preuni-type-css";
      s.textContent = CSS;
      document.head.appendChild(s);
    }

    withPluginApi("1.0", (api) => {
      api.serializeOnCreate("preuni_post_type");
      api.addPostClassesCallback((attrs) => {
        const clases = [];
        if (attrs.preuni_post_type === "solucion") clases.push("preuni-solucion");
        // Every reply of a question topic that isn't itself a question
        // (solutions, comments, plain replies) collapses behind
        // "Ver soluciones y comentarios" -- see services/preuni-hilo.js.
        if (
          attrs.post_number > 1 &&
          attrs.preuni_post_type !== "pregunta_adicional" &&
          attrs.topic?.preuni_fields?.clave
        ) {
          clases.push("preuni-hilo-respuesta");
        }
        return clases;
      });

      const hilo = api.container.lookup("service:preuni-hilo");
      api.onPageChange((url) => hilo.cambioDeRuta(url));
      // Writing a reply means you want to see the thread, and your own post
      // once it lands.
      api.onAppEvent("composer:opened", () => {
        if (api.getCurrentUser()) {
          hilo.setAbierto(true);
        }
      });
    });
  },
};
