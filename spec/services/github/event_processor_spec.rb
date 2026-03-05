require "rails_helper"

RSpec.describe Github::EventProcessor do
  let(:enricher) do
    instance_double(Github::Enricher, enrich_actor: nil, enrich_repository: nil)
  end

  subject(:processor) { described_class.new(enricher: enricher) }

  let(:push_event) do
    {
      "id" => "11223344",
      "type" => "PushEvent",
      "actor" => {
        "id" => 42,
        "login" => "octocat",
        "url" => "https://api.github.com/users/octocat",
        "avatar_url" => "https://avatars.githubusercontent.com/u/42"
      },
      "repo" => {
        "id" => 99,
        "name" => "octocat/hello-world",
        "url" => "https://api.github.com/repos/octocat/hello-world"
      },
      "payload" => {
        "push_id" => 7654321,
        "ref" => "refs/heads/main",
        "head" => "abc123def456",
        "before" => "789xyz"
      },
      "created_at" => "2025-01-15T10:00:00Z"
    }
  end

  describe "#process" do
    it "persists PushEvents" do
      expect { processor.process([push_event]) }.to change(GithubEvent, :count).by(1)
    end

    it "stores the structured fields correctly" do
      processor.process([push_event])
      event = GithubEvent.last

      expect(event.event_id).to eq("11223344")
      expect(event.ref).to eq("refs/heads/main")
      expect(event.head).to eq("abc123def456")
      expect(event.before).to eq("789xyz")
      expect(event.push_id).to eq(7654321)
      expect(event.repo_name).to eq("octocat/hello-world")
    end

    it "retains the full raw payload" do
      processor.process([push_event])
      event = GithubEvent.last

      expect(event.raw_payload["id"]).to eq("11223344")
      expect(event.raw_payload["type"]).to eq("PushEvent")
    end

    it "ignores non-PushEvent types" do
      issue_event = push_event.merge("id" => "99999999", "type" => "IssuesEvent")

      expect { processor.process([issue_event]) }.not_to change(GithubEvent, :count)
    end

    it "skips events that have already been ingested" do
      processor.process([push_event])

      expect { processor.process([push_event]) }.not_to change(GithubEvent, :count)
    end

    it "processes only the PushEvents when given a mixed list" do
      other = push_event.merge("id" => "55555555", "type" => "WatchEvent")

      expect { processor.process([push_event, other]) }.to change(GithubEvent, :count).by(1)
    end

    it "calls the enricher for each new event" do
      processor.process([push_event])

      expect(enricher).to have_received(:enrich_actor).once
      expect(enricher).to have_received(:enrich_repository).once
    end

    it "returns only the newly saved events" do
      processor.process([push_event])
      second_event = push_event.merge("id" => "22334455")
      results = processor.process([push_event, second_event])

      expect(results.size).to eq(1)
      expect(results.first.event_id).to eq("22334455")
    end
  end
end
