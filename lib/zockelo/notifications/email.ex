defmodule Zockelo.Notifications.Email do
  @moduledoc """
  Builds all notification email structs. Every email is multipart/alternative
  (text + HTML). No external URLs, images, or tracking pixels are included.

  Pass `locale: "de"` in opts for German. Defaults to "en".
  Caller is responsible for looking up Reply-To and List-Unsubscribe values.
  """

  import Swoosh.Email
  use Gettext, backend: ZockeloWeb.Gettext

  # ---------------------------------------------------------------------------
  # Game notification emails (player-facing)
  # ---------------------------------------------------------------------------

  def game_logged(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_game_logged(to_email, opts) end)
  end

  def game_confirmed(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_game_confirmed(to_email, opts) end)
  end

  def game_disputed(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_game_disputed(to_email, opts) end)
  end

  def game_auto_confirmed(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_game_auto_confirmed(to_email, opts) end)
  end

  # ---------------------------------------------------------------------------
  # Admin notification emails
  # ---------------------------------------------------------------------------

  def game_disputed_admin(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_game_disputed_admin(to_email, opts) end)
  end

  def new_player_via_invite_link(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_new_player_via_invite_link(to_email, opts) end)
  end

  # ---------------------------------------------------------------------------
  # Invitation emails
  # ---------------------------------------------------------------------------

  def player_invited(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_player_invited(to_email, opts) end)
  end

  def admin_invited(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_admin_invited(to_email, opts) end)
  end

  # ---------------------------------------------------------------------------
  # System / admin emails
  # ---------------------------------------------------------------------------

  def inactivity_warning(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_inactivity_warning(to_email, opts) end)
  end

  def tenant_deletion_requested(to_email, opts) do
    locale = Keyword.get(opts, :locale, "en")
    Gettext.with_locale(ZockeloWeb.Gettext, locale, fn -> build_tenant_deletion_requested(to_email, opts) end)
  end

  # ---------------------------------------------------------------------------
  # Private builders
  # ---------------------------------------------------------------------------

  defp build_game_logged(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] A game has been logged", app: app_name)
    text = dgettext("emails", "A new game has been logged in %{app}.\n\nView the game: %{url}\n\nIf you participated and the result is incorrect, dispute it from the game history page.\n\n%{footer}", app: app_name, url: game_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>A new game has been logged in <strong>%{app}</strong>.</p><p><a href=\"%{url}\">View game</a></p><p>If you participated and the result is incorrect, dispute it from the game history page.</p>%{unsub}", app: app_name, url: game_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_game_confirmed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] Game confirmed — ratings updated", app: app_name)
    text = dgettext("emails", "Your game in %{app} has been confirmed and ratings updated.\n\nView the game: %{url}\n\n%{footer}", app: app_name, url: game_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>Your game in <strong>%{app}</strong> has been confirmed and ratings updated.</p><p><a href=\"%{url}\">View game</a></p>%{unsub}", app: app_name, url: game_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_game_disputed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] A game result has been disputed", app: app_name)
    text = dgettext("emails", "A game you participated in on %{app} has been disputed. A league admin will review the result.\n\nView the game: %{url}\n\n%{footer}", app: app_name, url: game_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>A game you participated in on <strong>%{app}</strong> has been disputed.</p><p>A league admin will review the result and reinstate or void the game.</p><p><a href=\"%{url}\">View game</a></p>%{unsub}", app: app_name, url: game_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_game_auto_confirmed(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] Game auto-confirmed — ratings updated", app: app_name)
    text = dgettext("emails", "Your game in %{app} was not disputed within the confirmation window and has been automatically confirmed. Ratings updated.\n\nView the game: %{url}\n\n%{footer}", app: app_name, url: game_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>Your game in <strong>%{app}</strong> was not disputed and has been automatically confirmed. Ratings updated.</p><p><a href=\"%{url}\">View game</a></p>%{unsub}", app: app_name, url: game_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_game_disputed_admin(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    game_url = Keyword.get(opts, :game_url, "#")
    admin_url = Keyword.get(opts, :admin_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] Game disputed — admin review needed", app: app_name)
    text = dgettext("emails", "A game in your %{app} league has been disputed and requires admin review.\n\nView disputed game: %{url}\nAdmin panel: %{admin}\n\n%{footer}", app: app_name, url: game_url, admin: admin_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>A game in your <strong>%{app}</strong> league has been disputed and requires admin review.</p><p><a href=\"%{url}\">View disputed game</a> &middot; <a href=\"%{admin}\">Admin panel</a></p>%{unsub}", app: app_name, url: game_url, admin: admin_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_new_player_via_invite_link(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    admin_url = Keyword.get(opts, :admin_url, "#")
    reply_to = Keyword.get(opts, :reply_to)

    subject = dgettext("emails", "[%{app}] New player joined via invite link", app: app_name)
    text = dgettext("emails", "A new player has registered in %{app} via the invite link.\n\nView players: %{admin}\n\n%{footer}", app: app_name, admin: admin_url, footer: unsubscribe_footer(opts))
    html = simple_html(subject, dgettext("emails", "<p>A new player has registered in <strong>%{app}</strong> via the invite link.</p><p><a href=\"%{admin}\">View players in admin panel</a></p>%{unsub}", app: app_name, admin: admin_url, unsub: unsubscribe_html(opts)))

    base(to_email, subject, app_name, reply_to) |> text_body(text) |> html_body(html) |> maybe_list_unsubscribe(opts)
  end

  defp build_player_invited(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    magic_url = Keyword.fetch!(opts, :magic_url)

    subject = dgettext("emails", "You've been invited to %{app}", app: app_name)
    text = dgettext("emails", "You've been invited to join %{app}, a foosball Elo rating tracker.\n\nAccept your invitation: %{url}\n\nThis link expires in 15 minutes. If you didn't expect this, you can ignore it.", app: app_name, url: magic_url)
    html = simple_html(subject, dgettext("emails", "<p>You've been invited to join <strong>%{app}</strong>, a foosball Elo rating tracker.</p><p><a href=\"%{url}\" style=\"display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;\">Accept invitation</a></p><p style=\"color:#6b7280;font-size:0.85em;\">This link expires in 15 minutes. If you didn't expect this, you can ignore it.</p>", app: app_name, url: magic_url))

    system_base(to_email, subject) |> text_body(text) |> html_body(html)
  end

  defp build_admin_invited(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    magic_url = Keyword.fetch!(opts, :magic_url)

    subject = dgettext("emails", "You've been invited to manage %{app}", app: app_name)
    text = dgettext("emails", "You've been invited to manage %{app} as a league admin. You can invite players, manage game disputes, and configure league settings.\n\nAccept your invitation: %{url}\n\nThis link expires in 15 minutes. If you didn't expect this, you can ignore it.", app: app_name, url: magic_url)
    html = simple_html(subject, dgettext("emails", "<p>You've been invited to manage <strong>%{app}</strong> as a league admin.</p><p>You can invite players, manage game disputes, and configure league settings.</p><p><a href=\"%{url}\" style=\"display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;\">Accept invitation</a></p><p style=\"color:#6b7280;font-size:0.85em;\">This link expires in 15 minutes. If you didn't expect this, you can ignore it.</p>", app: app_name, url: magic_url))

    system_base(to_email, subject) |> text_body(text) |> html_body(html)
  end

  defp build_inactivity_warning(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    login_url = Keyword.fetch!(opts, :login_url)
    days = Keyword.get(opts, :days_remaining, 30)

    subject = dgettext("emails", "[%{app}] Your account will be deleted in %{days} days", app: app_name, days: days)
    text = dgettext("emails", "Your account in %{app} has been inactive for a long time.\n\nYour account will be permanently deleted in %{days} days unless you sign in.\n\nSign in to keep your account: %{url}", app: app_name, days: days, url: login_url)
    html = simple_html(subject, dgettext("emails", "<p>Your account in <strong>%{app}</strong> has been inactive for a long time.</p><p>Your account will be permanently deleted in <strong>%{days} days</strong> unless you sign in.</p><p><a href=\"%{url}\" style=\"display:inline-block;padding:10px 20px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold;\">Sign in to keep your account</a></p>", app: app_name, days: days, url: login_url))

    system_base(to_email, subject) |> text_body(text) |> html_body(html)
  end

  defp build_tenant_deletion_requested(to_email, opts) do
    app_name = Keyword.fetch!(opts, :app_name)
    grace_hours = Keyword.get(opts, :grace_hours, 48)

    subject = dgettext("emails", "[%{app}] League deletion has been requested", app: app_name)
    text = dgettext("emails", "A request has been made to delete your %{app} league. All data will be permanently deleted in %{hours} hours unless cancelled by a super admin. If this was a mistake, contact your system administrator immediately.", app: app_name, hours: grace_hours)
    html = simple_html(subject, dgettext("emails", "<p>A request has been made to delete your <strong>%{app}</strong> league.</p><p>All data will be permanently deleted in <strong>%{hours} hours</strong> unless cancelled by a super admin.</p><p style=\"color:#dc2626;font-weight:bold;\">If this was a mistake, contact your system administrator immediately.</p>", app: app_name, hours: grace_hours))

    system_base(to_email, subject) |> text_body(text) |> html_body(html)
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

    if reply_to, do: email |> reply_to(reply_to), else: email
  end

  defp system_base(to_email, _subject) do
    new()
    |> to(to_email)
    |> from({"Zockelo", smtp_from()})
  end

  defp maybe_list_unsubscribe(email, opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil -> email
      url ->
        email
        |> header("List-Unsubscribe", "<#{url}>")
        |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
    end
  end

  defp unsubscribe_footer(opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil -> ""
      url -> dgettext("emails", "To stop receiving these notifications: %{url}", url: url)
    end
  end

  defp unsubscribe_html(opts) do
    case Keyword.get(opts, :unsubscribe_url) do
      nil -> ""
      url -> "<p style=\"color:#9ca3af;font-size:0.8em;\"><a href=\"#{url}\" style=\"color:#9ca3af;\">#{dgettext("emails", "Unsubscribe from this notification")}</a></p>"
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
