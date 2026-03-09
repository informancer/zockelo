defmodule Zockelo.Notifications.Email do
  @moduledoc """
  Builds all notification email structs. Every email is multipart/alternative
  (text + HTML). No external URLs, images, or tracking pixels are included.

  Caller is responsible for looking up Reply-To and List-Unsubscribe values.
  """

  import Swoosh.Email

  alias Zockelo.Notifications

  # ---------------------------------------------------------------------------
  # Game notification emails (player-facing)
  # ---------------------------------------------------------------------------

  def game_logged(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] A game has been logged"

    text = """
    A new game has been logged in #{app_name}.

    View the game: #{game_url}

    If you participated in this game and the result is incorrect, you can
    dispute it from the game history page.

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>A new game has been logged in <strong>#{app_name}</strong>.</p>
    <p><a href="#{game_url}">View game</a></p>
    <p>If you participated in this game and the result is incorrect, you can
    dispute it from the game history page.</p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  def game_confirmed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] Game confirmed — ratings updated"

    text = """
    Your game in #{app_name} has been confirmed and ratings have been updated.

    View the game: #{game_url}

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>Your game in <strong>#{app_name}</strong> has been confirmed and ratings have been updated.</p>
    <p><a href="#{game_url}">View game</a></p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  def game_disputed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] A game result has been disputed"

    text = """
    A game you participated in on #{app_name} has been disputed.

    A league admin will review the result and either reinstate or void the game.

    View the game: #{game_url}

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>A game you participated in on <strong>#{app_name}</strong> has been disputed.</p>
    <p>A league admin will review the result and either reinstate or void the game.</p>
    <p><a href="#{game_url}">View game</a></p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  def game_auto_confirmed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] Game auto-confirmed — ratings updated"

    text = """
    Your game in #{app_name} was not disputed within the confirmation window
    and has been automatically confirmed. Ratings have been updated.

    View the game: #{game_url}

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>Your game in <strong>#{app_name}</strong> was not disputed within the confirmation
    window and has been automatically confirmed. Ratings have been updated.</p>
    <p><a href="#{game_url}">View game</a></p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  # ---------------------------------------------------------------------------
  # Admin notification emails
  # ---------------------------------------------------------------------------

  def game_disputed_admin(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    admin_url = Keyword.get(opts, :admin_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] Game disputed — admin review needed"

    text = """
    A game in your #{app_name} league has been disputed and requires admin review.

    View disputed game: #{game_url}
    Go to admin panel: #{admin_url}

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>A game in your <strong>#{app_name}</strong> league has been disputed and requires admin review.</p>
    <p><a href="#{game_url}">View disputed game</a> &middot; <a href="#{admin_url}">Admin panel</a></p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  def new_player_via_invite_link(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    admin_url = Keyword.get(opts, :admin_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = "[#{app_name}] New player joined via invite link"

    text = """
    A new player has registered in #{app_name} via the invite link.

    View players in admin panel: #{admin_url}

    #{unsubscribe_footer(opts)}
    """

    html = simple_html(subject, """
    <p>A new player has registered in <strong>#{app_name}</strong> via the invite link.</p>
    <p><a href="#{admin_url}">View players in admin panel</a></p>
    #{unsubscribe_html(opts)}
    """)

    base(to_email, subject, app_name, reply_to)
    |> text_body(text)
    |> html_body(html)
    |> maybe_list_unsubscribe(opts)
  end

  # ---------------------------------------------------------------------------
  # Invitation emails
  # ---------------------------------------------------------------------------

  def player_invited(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    magic_url = Keyword.fetch!(opts, :magic_url)

    subject = "You've been invited to #{app_name}"

    text = """
    You've been invited to join #{app_name}, a foosball Elo rating tracker.

    Accept your invitation: #{magic_url}

    This link expires in 15 minutes. If you didn't expect this invitation, you can ignore it.
    """

    html = simple_html(subject, """
    <p>You've been invited to join <strong>#{app_name}</strong>, a foosball Elo rating tracker.</p>
    <p><a href="#{magic_url}" style="display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;">Accept invitation</a></p>
    <p style="color:#6b7280;font-size:0.85em;">This link expires in 15 minutes. If you didn't expect this, you can ignore it.</p>
    """)

    system_base(to_email, subject)
    |> text_body(text)
    |> html_body(html)
  end

  def admin_invited(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    magic_url = Keyword.fetch!(opts, :magic_url)

    subject = "You've been invited to manage #{app_name}"

    text = """
    You've been invited to manage #{app_name} as a league admin.

    As an admin, you can invite players, manage game disputes, and configure
    league settings.

    Accept your invitation: #{magic_url}

    This link expires in 15 minutes. If you didn't expect this invitation, you can ignore it.
    """

    html = simple_html(subject, """
    <p>You've been invited to manage <strong>#{app_name}</strong> as a league admin.</p>
    <p>As an admin, you can invite players, manage game disputes, and configure league settings.</p>
    <p><a href="#{magic_url}" style="display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;">Accept invitation</a></p>
    <p style="color:#6b7280;font-size:0.85em;">This link expires in 15 minutes. If you didn't expect this, you can ignore it.</p>
    """)

    system_base(to_email, subject)
    |> text_body(text)
    |> html_body(html)
  end

  # ---------------------------------------------------------------------------
  # System / admin emails
  # ---------------------------------------------------------------------------

  def tenant_deletion_requested(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    grace_hours = Keyword.get(opts, :grace_hours, 48)

    subject = "[#{app_name}] League deletion has been requested"

    text = """
    A request has been made to delete your #{app_name} league.

    The league and all associated data will be permanently deleted in #{grace_hours} hours
    unless the deletion is cancelled by a super admin.

    If this was a mistake, contact your system administrator immediately.
    """

    html = simple_html(subject, """
    <p>A request has been made to delete your <strong>#{app_name}</strong> league.</p>
    <p>The league and all associated data will be permanently deleted in <strong>#{grace_hours} hours</strong>
    unless the deletion is cancelled by a super admin.</p>
    <p style="color:#dc2626;font-weight:bold;">If this was a mistake, contact your system administrator immediately.</p>
    """)

    system_base(to_email, subject)
    |> text_body(text)
    |> html_body(html)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp smtp_from do
    Application.get_env(:zockelo, :smtp_from, "noreply@zockelo.app")
  end

  defp base(to_email, _subject, app_name, reply_to) do
    email =
      new()
      |> to(to_email)
      |> from({app_name, smtp_from()})

    if reply_to do
      email |> reply_to(reply_to)
    else
      email
    end
  end

  defp system_base(to_email, _subject) do
    new()
    |> to(to_email)
    |> from({"Zockelo", smtp_from()})
  end

  defp maybe_list_unsubscribe(email, opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil ->
        email

      url ->
        email
        |> header("List-Unsubscribe", "<#{url}>")
        |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    end
  end

  defp unsubscribe_footer(opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil -> ""
      url -> "To stop receiving these notifications: #{url}"
    end
  end

  defp unsubscribe_html(opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil ->
        ""

      url ->
        "<p style=\"color:#9ca3af;font-size:0.8em;\"><a href=\"#{url}\" style=\"color:#9ca3af;\">Unsubscribe from this notification</a></p>"
    end
  end

  defp simple_html(title, body_html) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>#{title}</title></head>
    <body style="font-family:sans-serif;max-width:600px;margin:40px auto;color:#374151;line-height:1.6;">
    #{body_html}
    </body>
    </html>
    """
  end
end
