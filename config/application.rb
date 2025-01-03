require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Wrantle
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

   # Configure Action Mailer using MailPace
   config.action_mailer.delivery_method = :mailpace
   config.action_mailer.mailpace_settings = {
  api_token: "96c1941a-d05f-4f74-810a-6cf09e5b57c5"
}

    config.mission_control.jobs.base_controller_class = "ApplicationController"
    config.mission_control.jobs.http_basic_auth_enabled = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add node_modules to asset path for Primer components
    config.assets.paths << Rails.root.join("node_modules")
  end
end


require "view_component"
require "primer/view_components"
