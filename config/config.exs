# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :zockelo,
  ecto_repos: [Zockelo.Repo],
  generators: [timestamp_type: :utc_datetime]

# EventStore — use jsonb column type for efficient querying
config :eventstore,
  column_data_type: "jsonb",
  event_stores: [Zockelo.EventStore]

config :zockelo, event_stores: [Zockelo.EventStore]

config :zockelo, Zockelo.EventStore,
  serializer: EventStore.JsonbSerializer

# Commanded application
config :zockelo, Zockelo.CommandedApp,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Zockelo.EventStore
  ]

# Cloak — encryption vault (key loaded at runtime from CLOAK_KEY env var)
config :zockelo, Zockelo.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: {:system, "CLOAK_KEY"}}
  ]

# Oban — three named queues per observability spec
config :zockelo, Oban,
  repo: Zockelo.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    notifications: 10,
    scheduled: 5,
    critical: 2
  ]

# Configure the endpoint
config :zockelo, ZockeloWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ZockeloWeb.ErrorHTML, json: ZockeloWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Zockelo.PubSub,
  live_view: [signing_salt: "cgJTLG08"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :zockelo, Zockelo.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  zockelo: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ],
  sw: [
    args:
      ~w(js/service-worker.js --bundle --target=es2022 --outfile=../priv/static/assets/js/sw.js),
    cd: Path.expand("../assets", __DIR__),
    env: %{}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  zockelo: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
