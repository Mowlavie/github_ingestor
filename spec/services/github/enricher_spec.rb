require "rails_helper"

RSpec.describe Github::Enricher do
  let(:client) { instance_double(Github::Client) }

  subject(:enricher) { described_class.new(client: client) }

  let(:actor_event_data) do
    {
      "id" => 42,
      "login" => "octocat",
      "display_login" => "octocat",
      "avatar_url" => "https://avatars.githubusercontent.com/u/42",
      "url" => "https://api.github.com/users/octocat"
    }
  end

  let(:actor_api_response) do
    {
      "id" => 42,
      "login" => "octocat",
      "avatar_url" => "https://avatars.githubusercontent.com/u/42",
      "html_url" => "https://github.com/octocat",
      "bio" => "A friendly octopus"
    }
  end

  let(:repo_event_data) do
    {
      "id" => 99,
      "name" => "octocat/hello-world",
      "url" => "https://api.github.com/repos/octocat/hello-world"
    }
  end

  let(:repo_api_response) do
    {
      "id" => 99,
      "name" => "hello-world",
      "full_name" => "octocat/hello-world",
      "description" => "A sample repository",
      "html_url" => "https://github.com/octocat/hello-world"
    }
  end

  before do
    allow(enricher).to receive(:sleep)
  end

  describe "#enrich_actor" do
    context "when the actor does not exist yet" do
      before do
        allow(client).to receive(:fetch_url)
          .with(actor_event_data["url"])
          .and_return(actor_api_response)
      end

      it "creates a new Actor record" do
        expect { enricher.enrich_actor(actor_event_data) }.to change(Actor, :count).by(1)
      end

      it "stores the data from the API response" do
        actor = enricher.enrich_actor(actor_event_data)

        expect(actor.login).to eq("octocat")
        expect(actor.github_id).to eq(42)
        expect(actor.raw_payload["bio"]).to eq("A friendly octopus")
      end
    end

    context "when a fresh actor record already exists" do
      let!(:existing) { create(:actor, github_id: 42, login: "octocat", fetched_at: 1.hour.ago) }

      it "does not make an API call" do
        enricher.enrich_actor(actor_event_data)

        expect(client).not_to have_received(:fetch_url)
      end

      it "returns the existing actor" do
        result = enricher.enrich_actor(actor_event_data)

        expect(result).to eq(existing)
      end
    end

    context "when an existing actor record is stale" do
      let!(:stale_actor) { create(:actor, github_id: 42, login: "octocat", fetched_at: 2.days.ago) }

      before do
        allow(client).to receive(:fetch_url).and_return(actor_api_response)
      end

      it "refreshes the actor from the API" do
        enricher.enrich_actor(actor_event_data)

        expect(client).to have_received(:fetch_url)
      end
    end

    context "when the API fetch fails" do
      before do
        allow(client).to receive(:fetch_url).and_return(nil)
      end

      it "falls back to saving from event data without raising" do
        expect { enricher.enrich_actor(actor_event_data) }.to change(Actor, :count).by(1)
      end
    end

    it "returns nil for blank input" do
      expect(enricher.enrich_actor(nil)).to be_nil
      expect(enricher.enrich_actor({})).to be_nil
    end
  end

  describe "#enrich_repository" do
    context "when the repository does not exist yet" do
      before do
        allow(client).to receive(:fetch_url)
          .with(repo_event_data["url"])
          .and_return(repo_api_response)
      end

      it "creates a new Repository record" do
        expect { enricher.enrich_repository(repo_event_data) }.to change(Repository, :count).by(1)
      end

      it "stores the full_name and description" do
        repo = enricher.enrich_repository(repo_event_data)

        expect(repo.full_name).to eq("octocat/hello-world")
        expect(repo.description).to eq("A sample repository")
      end
    end

    context "when a fresh repository record already exists" do
      let!(:existing) { create(:repository, github_id: 99, fetched_at: 30.minutes.ago) }

      it "does not make an API call" do
        enricher.enrich_repository(repo_event_data)

        expect(client).not_to have_received(:fetch_url)
      end
    end
  end
end
