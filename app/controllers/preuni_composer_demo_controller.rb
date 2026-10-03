# frozen_string_literal: true

require "net/http"

# Public English demo of the question composer at /composer_en. The page and
# its extraction API are served by composer_demo.js on the host (bound to the
# Docker bridge); this controller only proxies to it and adds a per-IP limit
# on extractions. The demo can't publish anything.
#
# Inherits from ActionController::Base, not ApplicationController: the page is
# standalone HTML (no Ember app, no login), and Discourse's CSP would block its
# inline scripts -- it sends its own policy instead.
class PreuniComposerDemoController < ActionController::Base
  skip_forgery_protection

  DEMO_URL = ENV.fetch("PREUNI_COMPOSER_DEMO_URL", "http://172.17.0.1:3001")
  CSP = [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self' data: https://cdn.jsdelivr.net",
    "img-src 'self' data: blob:",
    "connect-src 'self'",
    "frame-ancestors 'none'",
  ].join("; ")
  EXTRACTIONS_PER_HOUR = 20

  def show
    upstream = demo(Net::HTTP::Get.new("/composer_en"))
    response.headers["Content-Security-Policy"] = CSP
    send_data upstream.body, type: "text/html; charset=utf-8", disposition: "inline", status: upstream.code.to_i
  rescue StandardError
    render plain: "The composer demo is not available right now.", status: 503
  end

  def status
    proxy_json Net::HTTP::Get.new("/composer_en/api/status")
  end

  def extract
    RateLimiter.new(nil, "preuni-composer-demo-#{request.remote_ip}", EXTRACTIONS_PER_HOUR, 1.hour).performed!
    req = Net::HTTP::Post.new("/composer_en/api/extract", "Content-Type" => "application/json")
    req.body = request.raw_post
    proxy_json req
  rescue RateLimiter::LimitExceeded
    render json: { error: "Demo limit reached (#{EXTRACTIONS_PER_HOUR} extractions per hour). Please try again later." }, status: 429
  end

  def extract_status
    id = params[:id].to_s
    return render(json: { error: "Invalid id." }, status: 400) unless id.match?(/\A[0-9a-f-]{36}\z/)
    proxy_json Net::HTTP::Get.new("/composer_en/api/extract/#{id}")
  end

  private

  def demo(req)
    uri = URI(DEMO_URL)
    Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 20) { |http| http.request(req) }
  end

  def proxy_json(req)
    upstream = demo(req)
    render json: upstream.body, status: upstream.code.to_i
  rescue StandardError
    render json: { error: "The extraction service is not available right now." }, status: 503
  end
end
