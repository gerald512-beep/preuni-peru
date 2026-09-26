# frozen_string_literal: true

# First-party click/view log for validating the MVP hypotheses (activation,
# retention, community, difficulty). Anonymous visitors carry a random
# visitante_id from localStorage; the same id keeps being sent after they
# register, so a visitor's anonymous history joins to their user_id.
class PreuniEvento < ActiveRecord::Base
  self.table_name = 'preuni_eventos'

  EVENTOS = %w[
    pregunta_vista
    cronometro_iniciado
    respuesta_anonima
    login_gate_click
    clave_mostrada
    clave_login_click
    hilo_abierto
    registro_errores_click
    busqueda_filtro
    busqueda_resultado_click
  ].freeze
end
