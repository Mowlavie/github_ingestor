require "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rspec/rails"
require "webmock/rspec"

ActiveRecord::Migration.maintain_test_schema!

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
