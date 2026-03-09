defmodule Zockelo.RateLimiter do
  @moduledoc """
  Thin wrapper around Hammer for use in LiveViews.

  Limits:
  - magic_link: 5 per 15 minutes per email+IP
  - join: 10 per 15 minutes per IP
  - token_verify: 20 per 15 minutes per IP
  """

  @limits %{
    magic_link: {5, :timer.minutes(15)},
    join: {10, :timer.minutes(15)},
    token_verify: {20, :timer.minutes(15)}
  }

  @doc "Returns :ok or {:error, :rate_limited}."
  def check(action, identifier) do
    {limit, window_ms} = Map.fetch!(@limits, action)
    key = "#{action}:#{identifier}"

    case Hammer.check_rate(key, window_ms, limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  @doc "Extracts IP string from a LiveView socket's connect_info peer_data."
  def peer_ip(socket) do
    case get_in(socket.private, [:connect_info, :peer_data]) do
      %{address: addr} -> addr |> Tuple.to_list() |> Enum.join(".")
      _ -> "unknown"
    end
  end
end
