module Github
  class Client
    BASE_URL = "https://api.github.com"
    EVENTS_PATH = "/events"
    RATE_LIMIT_THRESHOLD = 5

    attr_reader :logger

    def initialize
      @logger = Rails.logger
    end

    def fetch_events(etag: nil)
      response = connection.get(EVENTS_PATH) do |req|
        req.headers["If-None-Match"] = etag if etag
        req.headers["Accept"] = "application/vnd.github.v3+json"
        req.headers["User-Agent"] = "github-ingestor/1.0"
      end

      rate_limit = parse_rate_limit(response.headers)
      log_rate_limit(rate_limit)

      case response.status
      when 200
        {
          events: JSON.parse(response.body),
          etag: response.headers["etag"],
          rate_limit: rate_limit,
          not_modified: false
        }
      when 304
        logger.info "[client] No new events since last poll (304 Not Modified)"
        { events: [], etag: etag, rate_limit: rate_limit, not_modified: true }
      when 403, 429
        logger.warn "[client] Rate limited (#{response.status})"
        { events: [], etag: etag, rate_limit: rate_limit, not_modified: false }
      else
        logger.warn "[client] Unexpected response status: #{response.status}"
        { events: [], etag: etag, rate_limit: rate_limit, not_modified: false }
      end
    rescue Faraday::Error => e
      logger.error "[client] HTTP error fetching events: #{e.class} - #{e.message}"
      { events: [], etag: etag, rate_limit: {}, not_modified: false, error: e.message }
    end

    def fetch_url(url)
      response = connection.get(url) do |req|
        req.headers["Accept"] = "application/vnd.github.v3+json"
        req.headers["User-Agent"] = "github-ingestor/1.0"
      end

      case response.status
      when 200
        JSON.parse(response.body)
      when 304
        nil
      when 404
        logger.warn "[client] 404 for #{url}"
        nil
      when 403, 429
        logger.warn "[client] Rate limited (#{response.status}) fetching #{url}"
        nil
      else
        logger.warn "[client] #{response.status} fetching #{url}"
        nil
      end
    rescue Faraday::Error => e
      logger.warn "[client] HTTP error fetching #{url}: #{e.message}"
      nil
    end

    def rate_limited?(rate_limit)
      return false if rate_limit.nil? || rate_limit.empty?

      rate_limit[:remaining].to_i < RATE_LIMIT_THRESHOLD
    end

    def seconds_until_reset(rate_limit)
      return 60 if rate_limit.nil? || rate_limit[:reset].nil?

      reset_at = Time.at(rate_limit[:reset].to_i)
      [(reset_at - Time.now).ceil, 1].max
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.options.timeout = 30
        f.options.open_timeout = 10
        f.request :retry,
                  max: 2,
                  interval: 1,
                  backoff_factor: 2,
                  exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError],
                  methods: [:get]
        f.adapter Faraday.default_adapter
      end
    end

    def parse_rate_limit(headers)
      {
        limit: headers["x-ratelimit-limit"]&.to_i,
        remaining: headers["x-ratelimit-remaining"]&.to_i,
        reset: headers["x-ratelimit-reset"]&.to_i,
        used: headers["x-ratelimit-used"]&.to_i
      }
    end

    def log_rate_limit(rate_limit)
      return if rate_limit[:remaining].nil?

      reset_at = Time.at(rate_limit[:reset].to_i).strftime("%H:%M:%S")
      logger.info "[client] Rate limit: #{rate_limit[:remaining]}/#{rate_limit[:limit]} remaining (resets at #{reset_at})"
    end
  end
end
