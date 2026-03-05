module Github
  class EventProcessor
    attr_reader :logger, :enricher

    def initialize(enricher: Github::Enricher.new)
      @logger = Rails.logger
      @enricher = enricher
    end

    def process(events)
      push_events = events.select { |e| e["type"] == "PushEvent" }
      logger.info "[processor] #{events.size} events received, #{push_events.size} are PushEvents"

      push_events.filter_map { |event| process_event(event) }
    end

    private

    def process_event(event)
      event_id = event["id"].to_s

      if GithubEvent.exists?(event_id: event_id)
        logger.debug "[processor] Skipping duplicate event #{event_id}"
        return nil
      end

      payload = event["payload"] || {}
      actor_data = event["actor"] || {}
      repo_data = event["repo"] || {}

      github_event = GithubEvent.create!(
        event_id: event_id,
        event_type: event["type"],
        repo_identifier: repo_data["id"]&.to_s,
        repo_name: repo_data["name"],
        push_id: payload["push_id"],
        ref: payload["ref"],
        head: payload["head"],
        before: payload["before"],
        actor_github_id: actor_data["id"],
        repository_github_id: repo_data["id"],
        raw_payload: event
      )

      logger.info "[processor] Saved event #{event_id} (#{event["type"]}) for #{repo_data["name"]}"

      attach_enrichment(github_event, actor_data, repo_data)

      github_event
    rescue ActiveRecord::RecordNotUnique
      logger.debug "[processor] Duplicate event #{event["id"]} (concurrent write), skipping"
      nil
    rescue => e
      logger.error "[processor] Failed to process event #{event["id"]}: #{e.class} - #{e.message}"
      nil
    end

    def attach_enrichment(github_event, actor_data, repo_data)
      actor = enricher.enrich_actor(actor_data)
      repository = enricher.enrich_repository(repo_data)

      github_event.update_columns(
        actor_id: actor&.id,
        repository_id: repository&.id
      )
    rescue => e
      logger.warn "[processor] Enrichment failed for event #{github_event.event_id}: #{e.message}"
    end
  end
end
