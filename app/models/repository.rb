class Repository < ApplicationRecord
  has_many :github_events

  validates :github_id, presence: true, uniqueness: true
end
