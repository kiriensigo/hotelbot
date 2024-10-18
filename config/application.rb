require_relative "boot"
require "rails/all"
require 'line/bot'


# dotenv の読み込みを開発環境とテスト環境のみに制限
if Rails.env.development? || Rails.env.test?
  require 'dotenv/load'
end
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HotelLine
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2
    config.autoload_lib(ignore: %w[assets tasks])

    # 環境変数の読み込みを開発環境とテスト環境のみに制限
    if Rails.env.development? || Rails.env.test?
      config.before_configuration do
        env_file = File.join(Rails.root, 'config', 'local_env.yml')
        if File.exist?(env_file)
          YAML.load(File.open(env_file)).each do |key, value|
            ENV[key.to_s] = value
          end
        end
      end
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end