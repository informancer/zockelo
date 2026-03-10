defmodule ZockeloWeb.ErrorHTMLTest do
  use ZockeloWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  # Task 21.1 — custom error pages
  test "renders 404.html with proper content" do
    html = render_to_string(ZockeloWeb.ErrorHTML, "404", "html", [])
    assert html =~ "404"
    assert html =~ "Page Not Found"
    assert html =~ "Go to Home"
  end

  test "renders 500.html with proper content" do
    html = render_to_string(ZockeloWeb.ErrorHTML, "500", "html", [])
    assert html =~ "500"
    assert html =~ "Something Went Wrong"
    # Must NOT expose stack traces
    refute html =~ "stacktrace"
    refute html =~ "Erlang"
  end
end
