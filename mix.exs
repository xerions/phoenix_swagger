defmodule PhoenixSwagger.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_swagger,
     version: "0.3.3",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger],
     mod: {PhoenixSwagger, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
        {:poison, "~> 1.5 or ~> 2.0"},
        {:ex_json_schema, "~> 0.5.1", optional: :true},
        {:plug, "~> 1.1"}
    ]
  end

  defp description do
    "PhoenixSwagger is the library that provides swagger integration to the phoenix web framework."
  end

  defp package do
    [maintainers: ["Alexander Kuleshov"],
     licenses: ["MPL 2.0"],
     links: %{"Github" => "https://github.com/xerions/phoenix_swagger"}]
  end
end
