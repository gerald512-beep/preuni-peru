# Signup configuration: contact-consent fields + Spanish text for the
# email-code signup. Idempotent (matched by field name / translation key).
# Run inside the container:  rails runner /tmp/config_registro.rb
#
# The email-code signup (enable_local_logins_via_code) only shows custom
# fields in an extra "Ya casi terminas" step, and only when at least one
# field is required -- the consent question is that required field. It is a
# Sí/No choice (not a pre-ticked or mandatory checkbox) so consent stays
# freely given (Ley 29733), and it is editable from the profile so it can be
# withdrawn. WhatsApp and consent are private: never on profile or user card.

CONSENTIMIENTO = "¿Aceptas que te contactemos?"

privado = { editable: true, show_on_signup: true, show_on_profile: false, show_on_user_card: false, searchable: false }

ok = UserField.find_or_initialize_by(name: CONSENTIMIENTO)
ok.assign_attributes(privado.merge(
  field_type_enum: "dropdown", position: 3, requirement: "for_all_users", required: true,
  description: "Solo para preguntarte cómo te va con PreUni, por correo o WhatsApp. Puedes cambiar tu respuesta cuando quieras desde tu perfil.",
))
ok.save!
%w[Sí No].each { |v| ok.user_field_options.find_or_create_by!(value: v) }

wa = UserField.find_or_initialize_by(name: "WhatsApp")
wa.assign_attributes(privado.merge(
  field_type_enum: "text", position: 4, requirement: "optional", required: false,
  description: "Opcional. Solo lo usaremos si respondiste Sí a la pregunta anterior.",
))
wa.save!

CODE_LOGIN = {
  "check_your_email" => "Revisa tu correo",
  "code_instructions" => "Enviamos un código de 6 dígitos a <b>%{email}</b>. Escríbelo abajo para continuar.",
  "resend" => "Reenviar código",
  "resend_countdown" => "Reenviar código (%{count} s)",
  "code_resent" => "Te enviamos un código nuevo.",
  "use_different_email" => "Usar otro correo electrónico",
  "use_password_instead" => "Entrar con tu contraseña",
  "email_me_code" => "Enviarme un código de acceso por correo",
  "signup_instructions" => "Escribe tu correo electrónico para unirte. Te enviaremos un código para confirmarlo y listo.",
  "user_fields_title" => "Ya casi terminas",
  # Discourse shows a validation error under a required field as soon as this
  # step opens, hiding that field's description -- so the purpose of the
  # consent question is repeated here, where it's always visible.
  "user_fields_instructions" => "Solo unos datos más para crear tu cuenta. Si aceptas que te contactemos, será solo para preguntarte cómo te va con PreUni (por correo o WhatsApp). Puedes cambiar tu respuesta cuando quieras desde tu perfil.",
  "signup_details_title" => "Elige tu nombre de usuario y avatar",
  "account_details_title" => "Termina de crear tu cuenta",
  "account_details_instructions" => "Elige cómo te verá la comunidad antes de enviar tu cuenta para aprobación.",
  "create_password_optional" => "Crea una contraseña (opcional)",
  "submit_for_approval" => "Enviar para aprobación",
  "pending_approval_title" => "Tu cuenta está pendiente de aprobación.",
  "pending_approval_instructions" => "Un miembro del equipo debe aprobar tu cuenta antes de que puedas entrar. Te avisaremos por correo cuando esté aprobada.",
  "username_placeholder" => "Elige un nombre de usuario",
  "regenerate_username" => "Sugerir un nombre de usuario al azar",
  "change_avatar" => "Cambiar avatar",
  "username_taken" => "Ese nombre de usuario ya está en uso. Prueba otro.",
  "username_unavailable" => "Ese nombre de usuario no está disponible. Prueba %{suggestion}.",
}
CODE_LOGIN.each { |k, v| TranslationOverride.upsert!("es", "js.code_login.#{k}", v) }

CORREOS = {
  "email_login_code_mailer.title" => "Código de acceso por correo",
  "email_login_code_mailer.subject_template" => "%{code} es tu código de acceso",
  "email_login_code_mailer.text_body_template" => "Usa este código para terminar de entrar a %{site_name}:\n\n## %{code}\n\nEl código vence en %{minutes} minutos. Si no lo pediste, puedes ignorar este correo.\n",
  "password_reset_code_mailer.title" => "Código para restablecer la contraseña",
  "password_reset_code_mailer.subject_template" => "%{code} es tu código para restablecer la contraseña",
  "password_reset_code_mailer.text_body_template" => "Usa este código para restablecer tu contraseña en %{site_name}:\n\n## %{code}\n\nEl código vence en %{minutes} minutos. Si no lo pediste, puedes ignorar este correo.\n",
}
CORREOS.each { |k, v| TranslationOverride.upsert!("es", k, v) }

UserField.order(:position, :id).each do |f|
  puts [f.id, f.name, f.field_type_enum, f.requirement, "opts=#{f.user_field_options.pluck(:value)}",
        "signup=#{f.show_on_signup}", "profile=#{f.show_on_profile}", "card=#{f.show_on_user_card}"].join(" | ")
end
puts "es overrides: code_login=#{TranslationOverride.where(locale: 'es').where('translation_key LIKE ?', 'js.code_login.%').count}/#{CODE_LOGIN.size}, " \
     "emails=#{TranslationOverride.where(locale: 'es', translation_key: CORREOS.keys).count}/#{CORREOS.size}"
puts "enable_local_logins_via_code=#{SiteSetting.enable_local_logins_via_code} full_name_requirement=#{SiteSetting.full_name_requirement}"
