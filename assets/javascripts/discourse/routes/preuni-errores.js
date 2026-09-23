import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// The error log is personal: signed-out visitors go to the login page, which
// remembers where they were headed.
export default class PreuniErroresRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    if (!this.currentUser) {
      this.router.replaceWith("login");
    }
  }

  // Query params are sticky in Ember: without this the sidebar link would
  // reopen the page with the last question still highlighted.
  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("pregunta", null);
    }
  }

  titleToken() {
    return "Registro de errores";
  }
}
