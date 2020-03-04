defmodule PhoenixSwagger.Mixfile do
  use Mix.Project

  @version "0.8.2"

  def project do
    [
      app: :phoenix_swagger,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),

      # Docs
      source_url: "https://github.com/xerions/phoenix_swagger",
      homepage_url: "https://github.com/xerions/phoenix_swagger",
      docs: [
        extras: [
          "README.md",
          "docs/getting-started.md",
          "docs/schemas.md",
          "docs/operations.md",
          "docs/reusing-swagger-parameters.md",
          "docs/swagger-ui.md",
          "docs/schema-validation.md",
          "docs/test-helpers.md",
          "docs/live-reloading.md",
          "docs/json-api-helpers.md"
        ],
        main: "readme",
        source_ref: "v#{@version}"
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :plug], mod: {PhoenixSwagger, []}]
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
      {:jason, "~> 1.0", optional: true},
      {:ex_json_schema, "~> 0.6", optional: true},
      {:plug, "~> 1.4"},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
    ]
  end

  defp description do
    "PhoenixSwagger is the library that provides swagger integration to the phoenix web framework."
  end

  defp package do
    [
      maintainers: ["Alexander Kuleshov"],
      licenses: ["MPL 2.0"],
      links: %{
        "Github" => "https://github.com/xerions/phoenix_swagger",
        "Slack" => "https://elixir-lang.slack.com/messages/phoenix_swagger"
      }
    ]
  end
end
