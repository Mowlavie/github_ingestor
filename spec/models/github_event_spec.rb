require "rails_helper"

RSpec.describe GithubEvent, type: :model do
  it { should belong_to(:actor).optional }
  it { should belong_to(:repository).optional }
  it { should validate_presence_of(:event_id) }
  it { should validate_presence_of(:event_type) }

  it "validates uniqueness of event_id" do
    create(:github_event, event_id: "evt_1")
    duplicate = build(:github_event, event_id: "evt_1")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:event_id]).to include("has already been taken")
  end

  describe ".push_events" do
    it "returns only PushEvents" do
      push = create(:github_event, event_type: "PushEvent")
      other = create(:github_event, event_type: "IssueEvent")

      expect(GithubEvent.push_events).to include(push)
      expect(GithubEvent.push_events).not_to include(other)
    end
  end

  describe ".for_repo" do
    it "filters by repository name" do
      match = create(:github_event, repo_name: "rails/rails")
      other = create(:github_event, repo_name: "sinatra/sinatra")

      expect(GithubEvent.for_repo("rails/rails")).to include(match)
      expect(GithubEvent.for_repo("rails/rails")).not_to include(other)
    end
  end

  describe ".recent" do
    it "orders by created_at descending" do
      older = create(:github_event)
      newer = create(:github_event)

      expect(GithubEvent.recent.first).to eq(newer)
      expect(GithubEvent.recent.last).to eq(older)
    end
  end
end
