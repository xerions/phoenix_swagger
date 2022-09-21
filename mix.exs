defmodule PhoenixSwagger.Mixfile do
  use Mix.Project

  @source_url "https://github.com/xerions/phoenix_swagger"
  @version "0.8.3"

  def project do
    [
      app: :phoenix_swagger,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      xref: [exclude: [
        ExJsonSchema.Schema,
        ExJsonSchema.Validator
      ]]
    ]
  end

  def application do
    [
      applications: [:logger, :plug],
      mod: {PhoenixSwagger, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 2.2 or ~> 3.0 or ~> 5.0", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:ex_json_schema, "~> 0.7.1", optional: true},
      {:plug, "~> 1.11"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "PhoenixSwagger is the library that provides swagger "
        <> "integration to the phoenix web framework.",
      maintainers: ["Alexander Kuleshov"],
      licenses: ["MPL-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/phoenix_swagger/changelog.html",
        "GitHub" => @source_url,
        "Slack" => "https://elixir-lang.slack.com/messages/phoenix_swagger"
      },
      files: ~w(lib mix.exs .formatter.exs README.md CHANGELOG.md LICENSE config)
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        {:"LICENSE", [title: "License"]},
        {:"README.md", [title: "Overview"]},
        "guides/getting-started.md",
        "guides/schemas.md",
        "guides/operations.md",
        "guides/reusing-swagger-parameters.md",
        "guides/swagger-ui.md",
        "guides/schema-validation.md",
        "guides/test-helpers.md",
        "guides/live-reloading.md",
        "guides/json-api-helpers.md"
      ],
      groups_for_extras: [Guides: ~r/guides\/[^\/]+\.md/],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      homepage_url: @source_url,
      formatters: ["html"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
