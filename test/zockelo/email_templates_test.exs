defmodule Zockelo.EmailTemplatesTest do
  use ExUnit.Case, async: true

  alias Zockelo.Notifications.Email

  # Task 22.47 — no external URLs in email templates
  defp has_external_resource?(html) when is_binary(html) do
    # Check for img/link/script src/href with external URLs
    Regex.match?(~r/<(img|link|script)[^>]+(src|href)="https?:\/\/[^"]+"/i, html)
  end

  # Task 22.52 — all email templates have both html_body and text_body
  describe "email templates have both parts" do
    test "game_logged has html_body and text_body" do
      email = Email.game_logged("test@example.com",
        app_name: "Test",
        game_url: "http://localhost:4000/test/games/g1"
      )
      assert is_binary(email.html_body) and email.html_body != ""
      assert is_binary(email.text_body) and email.text_body != ""
    end

    test "game_logged has no external resources in HTML body" do
      email = Email.game_logged("test@example.com",
        app_name: "Test",
        game_url: "http://localhost:4000/test/games/g1"
      )
      refute has_external_resource?(email.html_body)
    end

    test "player_invited has html_body and text_body" do
      email = Email.player_invited("test@example.com",
        app_name: "Test",
        magic_url: "http://localhost:4000/auth/magic?token=abc"
      )
      assert is_binary(email.html_body) and email.html_body != ""
      assert is_binary(email.text_body) and email.text_body != ""
    end

    test "inactivity_warning has html_body and text_body" do
      email = Email.inactivity_warning("test@example.com",
        app_name: "Test",
        days_remaining: 30,
        login_url: "http://localhost:4000/test/login"
      )
      assert is_binary(email.html_body) and email.html_body != ""
      assert is_binary(email.text_body) and email.text_body != ""
    end
  end
end
