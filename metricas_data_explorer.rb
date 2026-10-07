# Creates/updates the 13 saved Data Explorer queries (H1-H4, events, contact list, ages).
# Idempotent (matched by name). Run inside the container:
#   rails runner /tmp/metricas_data_explorer.rb

# Accounts that are not real students: staff, plus members of the
# "excluir_metricas" group (demo/test accounts, e.g. user_test).
INTERNOS = <<~SQL.strip
  (u.admin OR u.moderator OR EXISTS (
    SELECT 1 FROM group_users gu JOIN groups g ON g.id = gu.group_id
    WHERE g.name = 'excluir_metricas' AND gu.user_id = u.id))
SQL

# Must match the field names in config_registro.rb. The yes option is
# "Sí, acepto" (plain "Sí" before 2026-10-02), so match on the prefix.
CONSENTIMIENTO = "¿Aceptas que te contactemos?"
NACIMIENTO = "Fecha de nacimiento"

# Age in whole years from the signup date field (stored as YYYY-MM-DD text);
# NULL when missing or malformed.
def edad_sql(user_id)
  <<~SQL.strip
    (SELECT DATE_PART('year', AGE(ucf.value::date))::int
       FROM user_custom_fields ucf JOIN user_fields uf ON ucf.name = 'user_field_' || uf.id
      WHERE uf.name = '#{NACIMIENTO}' AND ucf.user_id = #{user_id}
        AND ucf.value ~ '^\\d{4}-\\d{2}-\\d{2}$' LIMIT 1)
  SQL
end

TESTERS = <<~SQL.strip
  testers AS (
    SELECT u.id, u.username, u.created_at FROM users u
    WHERE u.id > 0 AND NOT u.staged AND NOT #{INTERNOS}
  )
SQL

# Browsers that were ever used by an internal account (your own testing,
# including logged-out tests from the same browser) are left out of event
# metrics.
STAFF_VIS = <<~SQL.strip
  staff_visitantes AS (
    SELECT DISTINCT e.visitante_id FROM preuni_eventos e
    JOIN users u ON u.id = e.user_id WHERE #{INTERNOS}
  ),
  e AS (
    SELECT * FROM preuni_eventos
    WHERE visitante_id NOT IN (SELECT visitante_id FROM staff_visitantes)
  )
SQL

QUERIES = [
  ["01 · H1 Activación (resumen)",
   "Escribe en 'invitados' cuántas personas contactaste. 'sin_confirmar_email' = se registraron pero no abrieron el correo de confirmación (fricción de onboarding, no falta de interés). Activación = testers que respondieron al menos una pregunta. Excluye cuentas admin/moderador.",
   <<~SQL],
    -- [params]
    -- int :invitados = 0

    WITH #{TESTERS},
    activos AS (
      SELECT DISTINCT r.user_id FROM preuni_respuestas r JOIN testers t ON t.id = r.user_id
    )
    SELECT
      :invitados AS invitados,
      (SELECT COUNT(*) FROM invited_users iu JOIN testers t ON t.id = iu.user_id) AS registrados_con_invitacion,
      (SELECT COUNT(*) FROM testers) AS registrados_total,
      (SELECT COUNT(*) FROM users u JOIN testers t ON t.id = u.id WHERE NOT u.active) AS sin_confirmar_email,
      (SELECT COUNT(*) FROM activos) AS respondieron_1_o_mas,
      CASE WHEN :invitados > 0
        THEN ROUND(100.0 * (SELECT COUNT(*) FROM activos) / :invitados, 1) END AS pct_activacion_sobre_invitados,
      ROUND(100.0 * (SELECT COUNT(*) FROM activos) / NULLIF((SELECT COUNT(*) FROM testers), 0), 1) AS pct_activacion_sobre_registrados
  SQL

  ["02 · Detalle por tester",
   "Una fila por tester: si confirmó su email (las invitaciones por enlace exigen confirmarlo antes de poder entrar), quién lo invitó, cuánto tardó en responder su primera pregunta, días de visita, si volvió en 7 días y cuánto participó.",
   <<~SQL],
    WITH #{TESTERS}
    SELECT
      t.id AS user_id,
      t.created_at AS registro,
      (SELECT u.active FROM users u WHERE u.id = t.id) AS email_confirmado,
      (SELECT ucf.value FROM user_custom_fields ucf JOIN user_fields uf ON ucf.name = 'user_field_' || uf.id
         WHERE uf.name = '#{CONSENTIMIENTO}' AND ucf.user_id = t.id LIMIT 1) AS acepta_contacto,
      #{edad_sql("t.id")} AS edad,
      (SELECT u.username FROM invited_users iu JOIN invites i ON i.id = iu.invite_id
         JOIN users u ON u.id = i.invited_by_id WHERE iu.user_id = t.id LIMIT 1) AS invitado_por,
      (SELECT MIN(r.created_at) FROM preuni_respuestas r WHERE r.user_id = t.id) AS primera_respuesta,
      ROUND(EXTRACT(EPOCH FROM (SELECT MIN(r.created_at) FROM preuni_respuestas r WHERE r.user_id = t.id) - t.created_at) / 60) AS minutos_hasta_1ra_respuesta,
      (SELECT COUNT(*) FROM preuni_respuestas r WHERE r.user_id = t.id) AS respuestas,
      (SELECT COUNT(DISTINCT r.created_at::date) FROM preuni_respuestas r WHERE r.user_id = t.id) AS dias_practicando,
      (SELECT COUNT(*) FROM user_visits v WHERE v.user_id = t.id) AS dias_con_visita,
      EXISTS (SELECT 1 FROM user_visits v WHERE v.user_id = t.id
                AND v.visited_at > t.created_at::date AND v.visited_at <= t.created_at::date + 7) AS volvio_en_7_dias,
      (SELECT ROUND(s.time_read / 60.0) FROM user_stats s WHERE s.user_id = t.id) AS minutos_leyendo,
      (SELECT COUNT(*) FROM posts p WHERE p.user_id = t.id AND p.post_number > 1 AND p.deleted_at IS NULL AND p.post_type = 1) AS publicaciones,
      (SELECT MAX(v.visited_at) FROM user_visits v WHERE v.user_id = t.id) AS ultima_visita
    FROM testers t
    ORDER BY t.created_at
  SQL

  ["03 · H2 Retención a 7 días (resumen)",
   "Retención = volvió algún día entre el 1 y el 7 después de registrarse. Solo cuenta a quienes ya cumplieron sus 7 días; los demás aparecen como 'aún en ventana'.",
   <<~SQL],
    WITH #{TESTERS},
    ret AS (
      SELECT t.id,
        t.created_at < NOW() - INTERVAL '7 days' AS ventana_completa,
        EXISTS (SELECT 1 FROM user_visits v WHERE v.user_id = t.id
                  AND v.visited_at > t.created_at::date AND v.visited_at <= t.created_at::date + 7) AS volvio
      FROM testers t
    )
    SELECT
      COUNT(*) FILTER (WHERE ventana_completa) AS testers_con_7_dias_cumplidos,
      COUNT(*) FILTER (WHERE ventana_completa AND volvio) AS volvieron,
      ROUND(100.0 * COUNT(*) FILTER (WHERE ventana_completa AND volvio)
            / NULLIF(COUNT(*) FILTER (WHERE ventana_completa), 0), 1) AS pct_retencion_7d,
      COUNT(*) FILTER (WHERE NOT ventana_completa) AS aun_en_ventana,
      COUNT(*) FILTER (WHERE NOT ventana_completa AND volvio) AS aun_en_ventana_que_ya_volvieron
    FROM ret
  SQL

  ["04 · H3 Comunidad (resumen)",
   "Soluciones, comentarios y apoyos publicados por testers. 'publicaciones_por_usuario_activo' divide entre quienes respondieron al menos una pregunta. Los likes y reacciones pueden solaparse si la reacción es el corazón.",
   <<~SQL],
    WITH #{TESTERS},
    pub AS (
      SELECT p.id, p.user_id, COALESCE(pcf.value, 'sin_tipo') AS tipo
      FROM posts p
      JOIN testers t ON t.id = p.user_id
      JOIN topics tp ON tp.id = p.topic_id AND tp.archetype = 'regular'
      LEFT JOIN post_custom_fields pcf ON pcf.post_id = p.id AND pcf.name = 'preuni_post_type'
      WHERE p.post_number > 1 AND p.deleted_at IS NULL AND p.post_type = 1
    ),
    pub_c AS (SELECT * FROM pub WHERE tipo <> 'pregunta_adicional'),
    activos AS (SELECT DISTINCT r.user_id FROM preuni_respuestas r JOIN testers t ON t.id = r.user_id)
    SELECT
      (SELECT COUNT(*) FROM pub_c WHERE tipo = 'solucion') AS soluciones,
      (SELECT COUNT(*) FROM pub_c WHERE tipo = 'comentario') AS comentarios,
      (SELECT COUNT(*) FROM pub_c WHERE tipo = 'sin_tipo') AS otras_respuestas,
      (SELECT COUNT(DISTINCT user_id) FROM pub_c) AS testers_que_publicaron,
      (SELECT COUNT(*) FROM activos) AS testers_activos,
      ROUND((SELECT COUNT(*) FROM pub_c)::numeric / NULLIF((SELECT COUNT(*) FROM activos), 0), 2) AS publicaciones_por_usuario_activo,
      (SELECT COUNT(*) FROM post_actions pa JOIN testers t ON t.id = pa.user_id
         WHERE pa.post_action_type_id = 2 AND pa.deleted_at IS NULL) AS likes_dados,
      (SELECT COUNT(*) FROM discourse_reactions_reaction_users ru JOIN testers t ON t.id = ru.user_id) AS reacciones_dadas,
      (SELECT COUNT(*) FROM post_voting_votes pv JOIN testers t ON t.id = pv.user_id) AS apoyos_a_soluciones
  SQL

  ["05 · H3 Publicaciones de testers",
   "Lista para lectura cualitativa: cada solución o comentario escrito por un tester, con enlace.",
   <<~SQL],
    WITH #{TESTERS}
    SELECT p.id AS post_id, p.user_id, COALESCE(pcf.value, 'sin_tipo') AS tipo,
           p.like_count AS likes, p.created_at
    FROM posts p
    JOIN testers t ON t.id = p.user_id
    JOIN topics tp ON tp.id = p.topic_id AND tp.archetype = 'regular'
    LEFT JOIN post_custom_fields pcf ON pcf.post_id = p.id AND pcf.name = 'preuni_post_type'
    WHERE p.post_number > 1 AND p.deleted_at IS NULL AND p.post_type = 1
      AND COALESCE(pcf.value, '') <> 'pregunta_adicional'
    ORDER BY p.created_at DESC
  SQL

  ["06 · H4 Intentos por pregunta (resumen)",
   "Indicador adelantado de H4: los chips de dificultad aparecen recién con 50 intentos por pregunta.",
   <<~SQL],
    WITH #{TESTERS},
    r AS (SELECT r.post_id FROM preuni_respuestas r JOIN testers t ON t.id = r.user_id),
    por_pregunta AS (SELECT post_id, COUNT(*) AS intentos FROM r GROUP BY post_id)
    SELECT
      (SELECT COUNT(*) FROM preuni_preguntas_indice) AS preguntas_publicadas,
      (SELECT COUNT(*) FROM por_pregunta) AS preguntas_con_intentos,
      (SELECT COUNT(*) FROM r) AS intentos_totales,
      ROUND((SELECT COUNT(*) FROM r)::numeric / NULLIF((SELECT COUNT(*) FROM por_pregunta), 0), 2) AS prom_por_pregunta_respondida,
      ROUND((SELECT COUNT(*) FROM r)::numeric / NULLIF((SELECT COUNT(*) FROM preuni_preguntas_indice), 0), 2) AS prom_sobre_todo_el_banco,
      (SELECT MAX(intentos) FROM por_pregunta) AS max_intentos_en_una_pregunta,
      (SELECT COUNT(*) FROM por_pregunta WHERE intentos >= 50) AS preguntas_con_50_o_mas
  SQL

  ["07 · H4 Preguntas más intentadas",
   "Intentos, % de acierto y tiempo por pregunta (cronómetro obligatorio para responder, así que siempre hay tiempo medido).",
   <<~SQL],
    WITH #{TESTERS}
    SELECT r.post_id, i.universidad, i.tema, COUNT(*) AS intentos,
      ROUND(100.0 * AVG(CASE WHEN r.respuesta = COALESCE(pcf.value, tcf.value) THEN 1 ELSE 0 END), 1) AS pct_acierto,
      ROUND(AVG(r.tiempo_segundos)) AS seg_promedio,
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.tiempo_segundos) AS seg_mediana
    FROM preuni_respuestas r
    JOIN testers t ON t.id = r.user_id
    LEFT JOIN preuni_preguntas_indice i ON i.post_id = r.post_id
    LEFT JOIN post_custom_fields pcf ON pcf.post_id = r.post_id AND pcf.name = 'preuni_clave'
    LEFT JOIN topic_custom_fields tcf ON tcf.topic_id = r.topic_id AND tcf.name = 'preuni_clave'
    GROUP BY r.post_id, i.universidad, i.tema
    ORDER BY intentos DESC
    LIMIT 100
  SQL

  ["08 · Clics en botones clave",
   "Cada evento del registro propio: total, últimos 7 días, usuarios con cuenta y visitantes anónimos únicos. Excluye navegadores usados alguna vez por cuentas staff.",
   <<~SQL],
    WITH #{STAFF_VIS}
    SELECT evento,
      COUNT(*) AS total,
      COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') AS ultimos_7_dias,
      COUNT(DISTINCT user_id) AS usuarios_con_cuenta,
      COUNT(DISTINCT visitante_id) FILTER (WHERE user_id IS NULL) AS visitantes_anonimos
    FROM e
    GROUP BY evento
    ORDER BY total DESC
  SQL

  ["09 · Embudo anónimo → registro",
   "Modo invitado (desde 2026-10-06 cualquiera practica sin cuenta). Visitantes sin cuenta: cuántos vieron una pregunta, respondieron como invitados (con resultado al instante), hicieron clic en 'Crea tu cuenta' (o, antes del modo invitado, en un aviso de 'inicia sesión'), luego crearon una cuenta desde ese mismo navegador, y cuántos pasaron sus respuestas de invitado a la cuenta.",
   <<~SQL],
    WITH #{STAFF_VIS},
    anon AS (
      SELECT visitante_id,
        BOOL_OR(evento = 'pregunta_vista') AS vio,
        BOOL_OR(evento = 'respuesta_anonima') AS respondio,
        COUNT(*) FILTER (WHERE evento = 'respuesta_anonima') AS respuestas,
        BOOL_OR(evento IN ('nudge_registro_click', 'login_gate_click', 'clave_login_click', 'hilo_login_click')) AS click_cuenta,
        MIN(created_at) AS primera_vez
      FROM e WHERE user_id IS NULL
      GROUP BY visitante_id
    ),
    registrados AS (
      SELECT DISTINCT a.visitante_id
      FROM anon a
      JOIN e ON e.visitante_id = a.visitante_id AND e.user_id IS NOT NULL
      JOIN users u ON u.id = e.user_id AND u.created_at >= a.primera_vez
    ),
    importaron AS (
      SELECT DISTINCT visitante_id FROM e
      WHERE evento = 'respuestas_importadas' AND COALESCE((datos->>'n')::int, 0) > 0
    )
    SELECT
      COUNT(*) AS visitantes_anonimos,
      COUNT(*) FILTER (WHERE vio) AS vieron_una_pregunta,
      COUNT(*) FILTER (WHERE respondio) AS respondieron_como_invitado,
      COALESCE(ROUND(AVG(respuestas) FILTER (WHERE respondio), 1), 0) AS respuestas_por_invitado,
      COUNT(*) FILTER (WHERE click_cuenta) AS clic_en_crear_cuenta,
      COUNT(*) FILTER (WHERE visitante_id IN (SELECT visitante_id FROM registrados)) AS luego_se_registraron,
      COUNT(*) FILTER (WHERE visitante_id IN (SELECT visitante_id FROM importaron)) AS importaron_respuestas
    FROM anon
  SQL

  ["10 · Actividad diaria (30 días)",
   "Por día: testers que visitaron, minutos de lectura, respuestas y visitantes anónimos únicos.",
   <<~SQL],
    WITH #{TESTERS},
    #{STAFF_VIS},
    dias AS (SELECT generate_series(CURRENT_DATE - 29, CURRENT_DATE, INTERVAL '1 day')::date AS dia)
    SELECT d.dia,
      (SELECT COUNT(*) FROM user_visits v JOIN testers t ON t.id = v.user_id WHERE v.visited_at = d.dia) AS testers_activos,
      (SELECT ROUND(COALESCE(SUM(v.time_read), 0) / 60.0) FROM user_visits v JOIN testers t ON t.id = v.user_id WHERE v.visited_at = d.dia) AS minutos_lectura,
      (SELECT COUNT(*) FROM preuni_respuestas r JOIN testers t ON t.id = r.user_id WHERE r.created_at::date = d.dia) AS respuestas,
      (SELECT COUNT(DISTINCT e.visitante_id) FROM e WHERE e.user_id IS NULL AND e.created_at::date = d.dia) AS visitantes_anonimos
    FROM dias d
    ORDER BY d.dia DESC
  SQL

  ["11 · Uso de filtros del buscador",
   "Cuántas veces se agregó cada valor en cada filtro, y cuántas búsquedas terminaron en un clic sobre un resultado.",
   <<~SQL],
    WITH #{STAFF_VIS},
    f AS (
      SELECT e.datos->>'faceta' AS faceta, jsonb_array_elements_text(e.datos->'agregados') AS valor
      FROM e WHERE e.evento = 'busqueda_filtro'
    )
    SELECT faceta, valor, COUNT(*) AS veces_agregado,
      (SELECT COUNT(*) FROM e WHERE e.evento = 'busqueda_resultado_click') AS clics_en_resultados_total
    FROM f
    GROUP BY faceta, valor
    ORDER BY faceta, veces_agregado DESC
  SQL

  ["12 · Testers que aceptan ser contactados",
   "Solo quienes respondieron \"Sí, acepto\" a '#{CONSENTIMIENTO}'. Úsala para elegir a quién llamar: ordenada por actividad. Si alguien cambia su respuesta a No en su perfil, desaparece de esta lista.",
   <<~SQL],
    WITH #{TESTERS},
    campo AS (
      SELECT uf.id, uf.name FROM user_fields uf
      WHERE uf.name IN ('#{CONSENTIMIENTO}', 'WhatsApp', 'Universidad objetivo', 'Especialidad objetivo')
    ),
    valores AS (
      SELECT ucf.user_id, c.name, ucf.value
      FROM user_custom_fields ucf JOIN campo c ON ucf.name = 'user_field_' || c.id
    )
    SELECT
      t.id AS user_id,
      (SELECT ue.email FROM user_emails ue WHERE ue.user_id = t.id AND ue.primary LIMIT 1) AS email,
      (SELECT v.value FROM valores v WHERE v.user_id = t.id AND v.name = 'WhatsApp') AS whatsapp,
      (SELECT v.value FROM valores v WHERE v.user_id = t.id AND v.name = 'Universidad objetivo') AS universidad_objetivo,
      (SELECT v.value FROM valores v WHERE v.user_id = t.id AND v.name = 'Especialidad objetivo') AS especialidad_objetivo,
      (SELECT COUNT(*) FROM preuni_respuestas r WHERE r.user_id = t.id) AS respuestas,
      (SELECT COUNT(*) FROM user_visits v WHERE v.user_id = t.id) AS dias_con_visita,
      (SELECT MAX(v.visited_at) FROM user_visits v WHERE v.user_id = t.id) AS ultima_visita,
      t.created_at AS registro
    FROM testers t
    WHERE EXISTS (SELECT 1 FROM valores v WHERE v.user_id = t.id AND v.name = '#{CONSENTIMIENTO}' AND v.value LIKE 'Sí%')
    ORDER BY respuestas DESC, dias_con_visita DESC
  SQL

  ["13 · Edad de los testers",
   "Cuántos testers hay por edad (de '#{NACIMIENTO}', pedida al registrarse desde el 2026-10-02) y cuánto practica cada grupo. 'sin dato' = cuentas creadas antes o fecha inválida.",
   <<~SQL],
    WITH #{TESTERS},
    e AS (
      SELECT t.id, #{edad_sql("t.id")} AS edad FROM testers t
    )
    SELECT
      CASE WHEN e.edad IS NULL OR e.edad < 10 OR e.edad > 80 THEN 'sin dato'
           WHEN e.edad <= 15 THEN '15 o menos'
           WHEN e.edad >= 21 THEN '21 o más'
           ELSE e.edad::text END AS edad,
      COUNT(*) AS testers,
      ROUND(AVG((SELECT COUNT(*) FROM preuni_respuestas r WHERE r.user_id = e.id)), 1) AS respuestas_promedio,
      ROUND(AVG((SELECT COUNT(*) FROM user_visits v WHERE v.user_id = e.id)), 1) AS dias_con_visita_promedio
    FROM e
    GROUP BY 1
    ORDER BY MIN(CASE WHEN e.edad BETWEEN 10 AND 80 THEN e.edad ELSE 999 END)
  SQL
]

SiteSetting.data_explorer_enabled = true

QUERIES.each do |name, description, sql|
  q = DiscourseDataExplorer::Query.find_or_initialize_by(name: name)
  q.description = description
  q.sql = sql
  q.user_id = Discourse.system_user.id
  q.hidden = false
  q.save!
  result = DiscourseDataExplorer::DataExplorer.run_query(q, { "invitados" => "10" })
  if result[:error]
    puts "FAIL #{name}: #{result[:error].message}"
  else
    puts "ok   #{name} (#{result[:pg_result].ntuples} rows)"
  end
end
