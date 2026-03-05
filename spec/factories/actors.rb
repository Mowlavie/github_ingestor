FactoryBot.define do
  factory :actor do
    sequence(:github_id) { |n| n }
    sequence(:login) { |n| "user_#{n}" }
    display_login { login }
    avatar_url { "https://avatars.githubusercontent.com/u/#{github_id}" }
    url { "https://api.github.com/users/#{login}" }
    raw_payload { { "id" => github_id, "login" => login } }
    fetched_at { Time.current }
  end
end
