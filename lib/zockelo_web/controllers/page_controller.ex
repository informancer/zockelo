defmodule ZockeloWeb.PageController do
  use ZockeloWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
