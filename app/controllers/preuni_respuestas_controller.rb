# frozen_string_literal: true

class PreuniRespuestasController < ApplicationController
  # The answer distribution and the difficulty chips are public statistics
  # (guest mode: visitors see them, but only registered answers feed them).
  requires_login except: [:distribucion, :difficulties]
  skip_before_action :verify_authenticity_token, if: :is_api?

  IMPORTAR_MAXIMO = 500

  def create
    post_id = params.require(:post_id).to_i
    respuesta = params.require(:respuesta).upcase

    unless PreuniRespuesta::VALID.include?(respuesta)
      return render json: { error: 'Respuesta inválida' }, status: :unprocessable_entity
    end

    post = Post.find_by(id: post_id)
    return render json: { error: 'Pregunta no encontrada' }, status: :not_found unless post

    if PreuniRespuesta.exists?(post_id: post_id, user_id: current_user.id)
      return render json: { error: 'Ya respondiste esta pregunta' }, status: :unprocessable_entity
    end

    PreuniRespuesta.create!(
      topic_id:        post.topic_id,
      post_id:         post_id,
      user_id:         current_user.id,
      respuesta:       respuesta,
      tiempo_segundos: params[:tiempo_segundos]&.to_i,
    )

    clave = clave_for(post)
    render json: {
      correcto:     respuesta == clave,
      clave:        clave,
      distribucion: distribucion_for(post_id),
    }
  end

  # Guest mode: answers given in this browser before signing up/logging in
  # (lib/preuni-invitado.js) move into the account. Skips anything that isn't
  # a question, an invalid letter, or a question this user already answered.
  def importar
    RateLimiter.new(current_user, "preuni-importar", 10, 1.hour).performed!

    entradas = params[:respuestas]
    entradas = entradas.values if entradas.respond_to?(:values) && !entradas.is_a?(Array)
    entradas = Array(entradas).first(IMPORTAR_MAXIMO)

    ya = PreuniRespuesta.where(user_id: current_user.id).pluck(:post_id).to_set
    desde = 90.days.ago
    importadas = 0

    entradas.each do |e|
      post_id = e[:post_id].to_i
      respuesta = e[:respuesta].to_s.upcase
      next if post_id <= 0 || ya.include?(post_id) || !PreuniRespuesta::VALID.include?(respuesta)

      # a question is the topic's first post or a linked question with its
      # own clave -- not a solution/comment reply (clave_for falls back to the topic)
      post = Post.find_by(id: post_id)
      next unless post && (post.post_number == 1 || post.custom_fields['preuni_clave'].present?)
      next unless clave_for(post).present?

      cuando = Time.zone.parse(e[:respondida_en].to_s) rescue nil
      cuando = Time.zone.now if cuando.nil? || cuando > Time.zone.now
      cuando = desde if cuando < desde
      tiempo = e[:tiempo_segundos].presence&.to_i

      registro = PreuniRespuesta.new(
        topic_id:        post.topic_id,
        post_id:         post_id,
        user_id:         current_user.id,
        respuesta:       respuesta,
        tiempo_segundos: tiempo,
        created_at:      cuando,
        updated_at:      cuando,
      )
      next unless registro.save   # e.g. a second tab imported it a moment earlier
      ya << post_id
      importadas += 1
    end

    render json: { importadas: importadas }
  end

  def distribucion
    post_id = params.require(:id).to_i
    post = Post.find_by(id: post_id)
    return render json: { error: 'No encontrada' }, status: :not_found unless post

    mia = current_user && PreuniRespuesta.find_by(post_id: post_id, user_id: current_user.id)

    render json: {
      distribucion: distribucion_for(post_id),
      mi_respuesta: mia&.respuesta,
      mi_tiempo: mia&.tiempo_segundos,
    }
  end

  private

  # Root question: clave lives on the topic. Additional question (a reply):
  # clave lives on that specific post.
  def clave_for(post)
    post.custom_fields['preuni_clave'].presence || post.topic.custom_fields['preuni_clave']
  end

  def distribucion_for(post_id)
    counts = PreuniRespuesta.where(post_id: post_id).group(:respuesta).count
    total  = counts.values.sum.to_f
    PreuniRespuesta::VALID.each_with_object({}) do |l, h|
      n = counts[l] || 0
      h[l] = { count: n, pct: total > 0 ? (n / total * 100).round(1) : 0 }
    end
  end
end
