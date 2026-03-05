FactoryBot.define do
  factory :repository do
    sequence(:github_id) { |n| n + 1000 }
    sequence(:name) { |n| "repo_#{n}" }
    full_name { "testorg/#{name}" }
    description { "A test repository" }
    url { "https://github.com/testorg/#{name}" }
    raw_payload { { "id" => github_id, "name" => name, "full_name" => full_name } }
    fetched_at { Time.current }
  end
end
