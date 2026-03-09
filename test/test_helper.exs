ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Zockelo.Repo, :manual)

# Clear EventStore between test runs to prevent stale event deserialization errors.
# The EventStore uses a separate DB that is not sandboxed by Ecto.
defmodule TestEventStoreHelper do
  def truncate! do
    config = Application.get_env(:zockelo, Zockelo.EventStore)
    opts = Keyword.take(config, [:username, :password, :hostname, :database, :port])

    {:ok, conn} = Postgrex.start_link(opts)
    Postgrex.query!(conn, "TRUNCATE events, streams, stream_events, subscriptions, snapshots RESTART IDENTITY CASCADE", [])
    GenServer.stop(conn)
  end
end

TestEventStoreHelper.truncate!()
