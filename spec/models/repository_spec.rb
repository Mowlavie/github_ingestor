require "rails_helper"

RSpec.describe Repository, type: :model do
  it { should have_many(:github_events) }
  it { should validate_presence_of(:github_id) }

  it "validates uniqueness of github_id" do
    create(:repository, github_id: 99)
    duplicate = build(:repository, github_id: 99)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:github_id]).to include("has already been taken")
  end
end
