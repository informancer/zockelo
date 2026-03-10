defmodule ZockeloWeb.Plugs.LocalePlug do
  @moduledoc """
  Resolves the request locale using:
    1. Player profile preference (if authenticated)
    2. Accept-Language header
    3. "en" fallback

  Sets Gettext locale for the request and stores it in conn assigns.
  """

  import Plug.Conn

  @supported ~w(en de)
  @default "en"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      player_locale(conn) ||
        header_locale(conn) ||
        @default

    Gettext.put_locale(ZockeloWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp player_locale(conn) do
    case conn.assigns[:current_user] do
      %{locale: locale} when locale in @supported -> locale
      _ -> nil
    end
  end

  defp header_locale(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_accept_language()
  end

  defp parse_accept_language(nil), do: nil

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(fn part ->
      [tag | _] = String.split(part, ";")
      tag |> String.trim() |> String.slice(0, 2) |> String.downcase()
    end)
    |> Enum.find(fn lang -> lang in @supported end)
  end
end
