defmodule Simple.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use Simple.Web, :controller
      use Simple.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: Simple.Web

      alias Simple.Repo
      import Ecto
      import Ecto.Query

      import Simple.Web.Router.Helpers
      import Simple.Web.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/simple/web/templates", namespace: Simple.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      import Simple.Web.Router.Helpers
      import Simple.Web.ErrorHelpers
      import Simple.Web.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      alias Simple.Repo
      import Ecto
      import Ecto.Query
      import Simple.Web.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
