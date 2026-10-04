import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

// Line under Discourse's welcome-banner headline ("¡Te damos la bienvenida de
// nuevo, X!"): the live size of the question bank, from GET /preuni/total
// (PreuniBusquedaController#total). Styled with the banner's own subheader
// class so it reads as part of the banner. Renders nothing until the count
// arrives, or if the request fails.

// The outlet sits outside the banner's title block, so align it the same way.
// Injected like the other plugin styles (the plugin's .scss is not served).
const CSS = `
.preuni-banner-total {
  text-align: var(--d-welcome-banner-text-alignment, center);
  margin: 0 auto var(--space-2);
}
`;

export default class PreuniTotalPreguntas extends Component {
  @tracked total = null;

  constructor(owner, args) {
    super(owner, args);
    if (!document.getElementById("preuni-banner-total-styles")) {
      const s = document.createElement("style");
      s.id = "preuni-banner-total-styles";
      s.textContent = CSS;
      document.head.appendChild(s);
    }
    this.cargar();
  }

  async cargar() {
    try {
      this.total = (await ajax("/preuni/total")).total;
    } catch {
      this.total = null;
    }
  }

  get texto() {
    const cifra = this.total.toLocaleString("es-PE");
    const palabra = this.total === 1 ? "pregunta" : "preguntas";
    return `Tenemos ${cifra} ${palabra} a la fecha y seguimos creciendo.`;
  }

  <template>
    {{#if this.total}}
      <p class="welcome-banner__subheader preuni-banner-total">{{this.texto}}</p>
    {{/if}}
  </template>
}
