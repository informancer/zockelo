defmodule ZockeloWeb.ErrorHTML do
  @moduledoc """
  Custom HTML error pages. No stack traces exposed in production.
  """
  use ZockeloWeb, :html

  embed_templates "error_html/*"

  # Fallback for any other status codes
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
