defmodule ZockeloWeb.ServiceWorkerController do
  use ZockeloWeb, :controller

  @doc """
  Serves the service worker script with the current build hash injected.

  The `__BUILD_HASH__` placeholder in the source is replaced at request time
  with the runtime build hash (from BUILD_HASH env var), which changes on each
  deployment and triggers the service worker update cycle in browsers.
  """
  def show(conn, _params) do
    build_hash = Application.get_env(:zockelo, :build_hash, "dev")
    source = Application.app_dir(:zockelo, "priv/static/assets/js/sw.js")

    sw_content =
      case File.read(source) do
        {:ok, content} -> String.replace(content, "__BUILD_HASH__", build_hash)
        {:error, _} -> "// Service worker not yet built"
      end

    conn
    |> put_resp_content_type("application/javascript")
    |> put_resp_header("service-worker-allowed", "/")
    |> send_resp(200, sw_content)
  end
end
