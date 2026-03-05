module Github
  class Enricher
    # How long before we consider cached actor/repo data stale enough to re-fetch
    STALE_AFTER = 24.hours

    # Delay between enrichment API calls to spread out our rate limit budget
    REQUEST_DELAY = 1.5

    attr_reader :logger, :client

    def initialize(client: Github::Client.new)
      @logger = Rails.logger
      @client = client
    end

    def enrich_actor(actor_data)
      return nil if actor_data.blank? || actor_data["id"].blank?

      github_id = actor_data["id"]
      existing = Actor.find_by(github_id: github_id)

      if existing && !stale?(existing.fetched_at)
        logger.debug "[enricher] Actor #{github_id} is fresh, skipping fetch"
        return existing
      end

      url = actor_data["url"]

      if url.present?
        fetch_and_upsert_actor(url, github_id, actor_data, existing)
      else
        upsert_actor_from_event(github_id, actor_data, existing)
      end
    rescue => e
      logger.warn "[enricher] Actor enrichment failed for #{actor_data["id"]}: #{e.message}"
      existing
    end

    def enrich_repository(repo_data)
      return nil if repo_data.blank? || repo_data["id"].blank?

      github_id = repo_data["id"]
      existing = Repository.find_by(github_id: github_id)

      if existing && !stale?(existing.fetched_at)
        logger.debug "[enricher] Repository #{github_id} is fresh, skipping fetch"
        return existing
      end

      url = repo_data["url"]

      if url.present?
        fetch_and_upsert_repository(url, github_id, repo_data, existing)
      else
        upsert_repository_from_event(github_id, repo_data, existing)
      end
    rescue => e
      logger.warn "[enricher] Repository enrichment failed for #{repo_data["id"]}: #{e.message}"
      existing
    end

    private

    def stale?(fetched_at)
      fetched_at.nil? || fetched_at < STALE_AFTER.ago
    end

    def fetch_and_upsert_actor(url, github_id, fallback_data, existing)
      sleep(REQUEST_DELAY)
      data = client.fetch_url(url)

      unless data
        logger.debug "[enricher] Could not fetch actor #{github_id} from API, using event data"
        return upsert_actor_from_event(github_id, fallback_data, existing)
      end

      attrs = {
        github_id: github_id,
        login: data["login"],
        display_login: data["login"],
        avatar_url: data["avatar_url"],
        url: data["html_url"] || data["url"],
        raw_payload: data,
        fetched_at: Time.current
      }

      if existing
        existing.update!(attrs)
        logger.info "[enricher] Updated actor #{github_id} (#{data["login"]})"
        existing
      else
        actor = Actor.create!(attrs)
        logger.info "[enricher] Created actor #{github_id} (#{data["login"]})"
        actor
      end
    end

    def fetch_and_upsert_repository(url, github_id, fallback_data, existing)
      sleep(REQUEST_DELAY)
      data = client.fetch_url(url)

      unless data
        logger.debug "[enricher] Could not fetch repository #{github_id} from API, using event data"
        return upsert_repository_from_event(github_id, fallback_data, existing)
      end

      attrs = {
        github_id: github_id,
        name: data["name"],
        full_name: data["full_name"],
        description: data["description"],
        url: data["html_url"] || data["url"],
        raw_payload: data,
        fetched_at: Time.current
      }

      if existing
        existing.update!(attrs)
        logger.info "[enricher] Updated repository #{github_id} (#{data["full_name"]})"
        existing
      else
        repo = Repository.create!(attrs)
        logger.info "[enricher] Created repository #{github_id} (#{data["full_name"]})"
        repo
      end
    end

    def upsert_actor_from_event(github_id, actor_data, existing)
      attrs = {
        github_id: github_id,
        login: actor_data["login"] || "unknown",
        display_login: actor_data["display_login"] || actor_data["login"],
        avatar_url: actor_data["avatar_url"],
        url: actor_data["url"],
        raw_payload: actor_data,
        fetched_at: Time.current
      }

      if existing
        existing.update!(attrs)
        existing
      else
        Actor.create!(attrs)
      end
    end

    def upsert_repository_from_event(github_id, repo_data, existing)
      attrs = {
        github_id: github_id,
        name: repo_data["name"]&.split("/")&.last || repo_data["name"],
        full_name: repo_data["name"],
        url: repo_data["url"],
        raw_payload: repo_data,
        fetched_at: Time.current
      }

      if existing
        existing.update!(attrs)
        existing
      else
        Repository.create!(attrs)
      end
    end
  end
end
