defmodule Zockelo.CommandedApp do
  use Commanded.Application,
    otp_app: :zockelo,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: Zockelo.EventStore
    ]

  router Zockelo.Domain.Router
end
