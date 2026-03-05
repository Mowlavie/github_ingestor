require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module GithubIngestor
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true

    config.logger = ActiveSupport::Logger.new($stdout)
    config.logger.formatter = proc do |severity, time, _progname, msg|
      "[#{time.strftime('%Y-%m-%dT%H:%M:%S')}] #{severity}: #{msg}\n"
    end

    config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym

    config.autoload_paths += [Rails.root.join("app/services")]
  end
end
