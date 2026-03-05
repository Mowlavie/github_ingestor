class GithubEvent < ApplicationRecord
  belongs_to :actor, optional: true
  belongs_to :repository, optional: true

  validates :event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  scope :push_events, -> { where(event_type: "PushEvent") }
  scope :for_repo, ->(name) { where(repo_name: name) }
  scope :recent, -> { order(created_at: :desc) }
end
