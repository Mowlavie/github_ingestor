module Github
  class IngestionRunner
    POLL_INTERVAL = 60
    RATE_LIMIT_BUFFER = 5

    attr_reader :logger, :client, :processor

    def initialize(client: Github::Client.new, processor: Github::EventProcessor.new)
      @logger = Rails.logger
      @client = client
      @processor = processor
    end

    def run
      continuous = ENV.fetch("CONTINUOUS", "false") == "true"
      logger.info "[runner] Starting ingestion (mode=#{continuous ? "continuous" : "single"})"

      etag = nil

      loop do
        etag = run_cycle(etag)
        break unless continuous

        logger.info "[runner] Sleeping #{POLL_INTERVAL}s before next poll"
        sleep(POLL_INTERVAL)
      end

      logger.info "[runner] Ingestion finished"
    end

    private

    def run_cycle(etag)
      result = client.fetch_events(etag: etag)

      if result[:error]
        logger.error "[runner] Fetch failed: #{result[:error]}"
        return etag
      end

      rate_limit = result[:rate_limit]

      if client.rate_limited?(rate_limit)
        wait = client.seconds_until_reset(rate_limit) + RATE_LIMIT_BUFFER
        logger.warn "[runner] Rate limit nearly exhausted (#{rate_limit[:remaining]} remaining). Waiting #{wait}s for reset"
        sleep(wait)
        return etag
      end

      if result[:not_modified]
        logger.info "[runner] No new events since last cycle"
      else
        saved = processor.process(result[:events])
        logger.info "[runner] Cycle complete: #{saved.compact.size} new events saved out of #{result[:events].size} fetched"
      end

      result[:etag]
    end
  end
end
