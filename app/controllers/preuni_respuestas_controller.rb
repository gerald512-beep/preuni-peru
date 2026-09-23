# frozen_string_literal: true

class PreuniRespuestasController < ApplicationController
  requires_login
  skip_before_action :verify_authenticity_token, if: :is_api?

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

  def distribucion
    post_id = params.require(:id).to_i
    post = Post.find_by(id: post_id)
    return render json: { error: 'No encontrada' }, status: :not_found unless post

    mi_respuesta = current_user ?
      PreuniRespuesta.find_by(post_id: post_id, user_id: current_user.id)&.respuesta :
      nil

    render json: {
      distribucion: distribucion_for(post_id),
      mi_respuesta: mi_respuesta,
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
