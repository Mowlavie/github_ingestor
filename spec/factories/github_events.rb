FactoryBot.define do
  factory :github_event do
    sequence(:event_id) { |n| "event_#{n}" }
    event_type { "PushEvent" }
    sequence(:repo_identifier) { |n| (n + 500).to_s }
    repo_name { "testuser/testrepo" }
    sequence(:push_id) { |n| n + 9000 }
    ref { "refs/heads/main" }
    sequence(:head) { |n| "abc#{n.to_s.rjust(35, "0")}" }
    sequence(:before) { |n| "def#{n.to_s.rjust(35, "0")}" }
    raw_payload { { "id" => event_id, "type" => event_type } }
  end
end
