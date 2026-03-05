require "rails_helper"

RSpec.describe Actor, type: :model do
  it { should have_many(:github_events) }
  it { should validate_presence_of(:github_id) }
  it { should validate_uniqueness_of(:github_id) }
  it { should validate_presence_of(:login) }
end
