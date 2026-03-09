defmodule Zockelo.Auth.Email do
  import Swoosh.Email

  @doc """
  Builds a magic link email.
  """
  def magic_link(to_email, magic_link_url) do
    new()
    |> to(to_email)
    |> from({"Zockelo", "noreply@zockelo.app"})
    |> subject("Your Zockelo login link")
    |> text_body("""
    Click the link below to log in to Zockelo.

    #{magic_link_url}

    This link expires in 15 minutes and can only be used once.
    If you did not request this, you can ignore this email.
    """)
  end
end
