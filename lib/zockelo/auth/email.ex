defmodule Zockelo.Auth.Email do
  @moduledoc "System emails: magic links and email change verification."

  import Swoosh.Email

  defp smtp_from do
    Application.get_env(:zockelo, :smtp_from, "noreply@zockelo.app")
  end

  @doc "Builds a magic link email (system email — no Reply-To, no unsubscribe)."
  def magic_link(to_email, magic_link_url) do
    subject = "Your sign-in link"

    text = """
    Click the link below to sign in.

    #{magic_link_url}

    This link expires in 15 minutes and can only be used once.
    If you did not request this, you can ignore this email.
    """

    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>#{subject}</title></head>
    <body style="font-family:sans-serif;max-width:600px;margin:40px auto;color:#374151;line-height:1.6;">
    <p>Click the link below to sign in.</p>
    <p><a href="#{magic_link_url}" style="display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;">Sign in</a></p>
    <p style="color:#6b7280;font-size:0.85em;">This link expires in 15 minutes and can only be used once.<br>
    If you did not request this, you can safely ignore this email.</p>
    </body>
    </html>
    """

    new()
    |> to(to_email)
    |> from({"Zockelo", smtp_from()})
    |> subject(subject)
    |> text_body(text)
    |> html_body(html)
  end
end
