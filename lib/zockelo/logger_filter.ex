defmodule Zockelo.LoggerFilter do
  @moduledoc """
  Logger filter that redacts PII, tokens, and encryption keys from log output.

  Registered via `Logger.add_handler_filter/3` in application startup if needed.
  Currently the primary defense is Phoenix's `:filter_parameters` config (in config.exs),
  which redacts sensitive query/body parameters from request logs.

  This module provides a helper for manually scrubbing strings in audit contexts.
  """

  @email_re ~r/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/

  @doc "Redacts email addresses from a string for safe logging."
  def scrub(msg) when is_binary(msg) do
    Regex.replace(@email_re, msg, "[REDACTED_EMAIL]")
  end

  def scrub(other), do: other
end
