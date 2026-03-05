module Api
  module V1
    class EventsController < ApplicationController
      def index
        events = GithubEvent.recent.includes(:actor, :repository)
        events = events.for_repo(params[:repo]) if params[:repo].present?

        limit = params.fetch(:limit, 50).to_i.clamp(1, 200)
        events = events.limit(limit)

        render json: {
          count: events.size,
          events: events.map { |e| serialize_event(e) }
        }
      end

      def show
        event = GithubEvent.find_by!(event_id: params[:event_id])
        render json: serialize_event(event, full: true)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found" }, status: :not_found
      end

      private

      def serialize_event(event, full: false)
        data = {
          event_id: event.event_id,
          repo_name: event.repo_name,
          push_id: event.push_id,
          ref: event.ref,
          head: event.head,
          before: event.before,
          actor: event.actor&.login,
          repository: event.repository&.full_name,
          ingested_at: event.created_at
        }

        data[:raw_payload] = event.raw_payload if full
        data
      end
    end
  end
end
