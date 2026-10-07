import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service from "@ember/service";

// Whether the replies (solutions + comments) of the current question topic
// are expanded. Collapsed by default so a student practicing doesn't see the
// answer by scrolling past the question; one click opens them, for guests
// too (guest mode, see connectors/post-links/preuni-clave.gjs).
// Shared across every "Ver soluciones y comentarios" button in the topic
// (a reading cluster has one per question) and drives the body class the
// CSS in preuni-post-type.js keys on.
export default class PreuniHilo extends Service {
  @tracked abierto = false;
  topicId = null;
  postObjetivo = null;

  setAbierto(valor) {
    this.abierto = valor;
    document.body.classList.toggle("preuni-hilo-abierto", valor);
  }

  toggle() {
    this.setAbierto(!this.abierto);
  }

  // Scrolling inside a topic rewrites the URL's post number, so only a change
  // of topic resets the collapse -- not every URL change.
  cambioDeRuta(url) {
    const m = url.match(/\/t\/[^/]+\/(\d+)(?:\/(\d+))?/);
    const topicId = m ? Number(m[1]) : null;
    if (topicId !== this.topicId) {
      this.topicId = topicId;
      this.setAbierto(false);
    }
    this.postObjetivo = m?.[2] ? Number(m[2]) : null;
    if (this.postObjetivo) {
      this.#esperarObjetivo(this.postObjetivo);
    }
  }

  // The page-change hook fires before the post stream renders (up to ~1s on
  // a cold load), so wait for the target post to exist.
  #esperarObjetivo(numero) {
    let intentos = 0;
    const id = setInterval(() => {
      const listo = document.querySelector(
        `.topic-post[data-post-number="${numero}"]`
      );
      if (listo || numero !== this.postObjetivo || ++intentos >= 50) {
        clearInterval(id);
        if (listo && numero === this.postObjetivo) {
          this.#abrirSiObjetivoOculto(numero);
        }
      }
    }, 100);
  }

  // A link straight to a solution/comment (a notification, a shared link)
  // would otherwise land on a hidden post.
  #abrirSiObjetivoOculto(numero) {
    const post = document.querySelector(
      `.topic-post.preuni-hilo-respuesta[data-post-number="${numero}"]`
    );
    if (post && !this.abierto) {
      this.setAbierto(true);
      // Discourse already scrolled while this post had zero height, and its
      // post-stream anchoring would override a plain scrollIntoView -- its
      // own jump lands correctly under the header and stays there.
      requestAnimationFrame(() =>
        getOwner(this).lookup("controller:topic").send("jumpToPost", numero)
      );
    }
  }
}
