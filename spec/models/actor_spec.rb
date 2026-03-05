require "rails_helper"

RSpec.describe Actor, type: :model do
  it { should have_many(:github_events) }
  it { should validate_presence_of(:github_id) }
  it { should validate_presence_of(:login) }

  it "validates uniqueness of github_id" do
    create(:actor, github_id: 42, login: "octocat")
    duplicate = build(:actor, github_id: 42, login: "different")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:github_id]).to include("has already been taken")
  end
end
