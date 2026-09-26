# frozen_string_literal: true

# POST /preuni/evento -- sent with navigator.sendBeacon so it survives the
# page navigation that many tracked clicks trigger (login links, results).
# A beacon can't set the XHR/JSON headers or the CSRF token, so both checks
# are skipped: this endpoint only appends an analytics row, and the worst a
# forged request could do is log a fake click. Rate-limited per IP instead.
class PreuniEventosController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :check_xhr
  skip_before_action :preload_json
  skip_before_action :redirect_to_login_if_required

  MAX_DATOS_BYTES = 2_000

  def create
    # Search-engine renderers run the page's JS too; their visits aren't
    # students and would inflate the anonymous-visitor numbers.
    return head :no_content if CrawlerDetection.crawler?(request.user_agent, request.headers["HTTP_VIA"])

    evento = params[:evento].to_s
    visitante_id = params[:visitante_id].to_s
    return head :bad_request unless PreuniEvento::EVENTOS.include?(evento)
    return head :bad_request unless visitante_id.match?(/\A[A-Za-z0-9-]{8,64}\z/)

    # Per browser, not just per IP: a classroom of testers shares one IP, and
    # a per-IP-only limit silently dropped their events (verified: 30 visitors
    # behind one IP lost every event past the 120th in a minute).
    RateLimiter.new(nil, "preuni_evento_v_#{visitante_id}", 60, 1.minute).performed!
    RateLimiter.new(nil, "preuni_evento_ip_#{request.remote_ip}", 1500, 1.minute).performed!

    datos = params[:datos].respond_to?(:to_unsafe_h) ? params[:datos].to_unsafe_h : {}
    datos = {} if datos.to_json.bytesize > MAX_DATOS_BYTES

    PreuniEvento.create!(
      evento: evento,
      user_id: current_user&.id,
      visitante_id: visitante_id,
      topic_id: entero(params[:topic_id]),
      post_id: entero(params[:post_id]),
      datos: datos,
      created_at: Time.zone.now,
    )
    head :no_content
  rescue RateLimiter::LimitExceeded
    head :too_many_requests
  end

  private

  def entero(valor)
    valor.to_s.match?(/\A\d{1,18}\z/) ? valor.to_i : nil
  end
end
