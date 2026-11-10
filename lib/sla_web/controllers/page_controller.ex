defmodule SlaWeb.PageController do
  use SlaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
