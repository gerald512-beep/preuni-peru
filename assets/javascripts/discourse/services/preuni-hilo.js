import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";

// Whether the replies (solutions + comments) of the current question topic
// are expanded. Collapsed by default so a student practicing doesn't see the
// answer by scrolling past the question; one click opens them for signed-in
// users. Signed-out visitors get a login prompt instead (soft gate, see
// connectors/post-links/preuni-clave.gjs) and nothing here opens it for them.
// Shared across every "Ver soluciones y comentarios" button in the topic
// (a reading cluster has one per question) and drives the body class the
// CSS in preuni-post-type.js keys on.
export default class PreuniHilo extends Service {
  @service currentUser;
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
    if (post && !this.currentUser) {
      // Shared link to a solution, visitor not signed in: show the question
      // and its login prompt rather than an empty spot where the reply was.
      // Discourse's scroll lock (lib/lock-on.js) keeps re-anchoring on the
      // zero-height reply for about a second and overrides a plain scroll.
      this.#subirAlInicio();
      return;
    }
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

  // The lock lets go when it sees a wheel event on body, so keep releasing it
  // and scrolling up for a couple of seconds (it can start late), unless the
  // visitor starts scrolling on their own.
  #subirAlInicio() {
    const eventos = ["touchstart", "wheel", "keydown", "mousedown"];
    let intentos = 0;
    const parar = () => {
      clearInterval(id);
      eventos.forEach((e) => window.removeEventListener(e, alUsuario, true));
    };
    const alUsuario = (e) => e.isTrusted && parar();
    eventos.forEach((e) =>
      window.addEventListener(e, alUsuario, { capture: true, passive: true })
    );
    const id = setInterval(() => {
      document.body.dispatchEvent(new Event("wheel"));
      window.scrollTo(0, 0);
      if (++intentos >= 25) {
        parar();
      }
    }, 100);
  }
}
