defmodule PhoenixSwagger.Mixfile do
  use Mix.Project

  @source_url "https://github.com/xerions/phoenix_swagger"
  @version "0.8.4"

  def project do
    [
      app: :phoenix_swagger,
      version: @version,
      elixir: "~> 1.16",
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
      extra_applications: extra_applications(Mix.env()) ++ [:logger],
      mod: {PhoenixSwagger, []}
    ]
  end

  defp extra_applications(:test) do
    [:jason, :ex_json_schema]
  end
  defp extra_applications(_), do: []

  defp deps do
    [
      {:poison, "~> 6.0.0", optional: true},
      {:jason, "~> 1.4.4", optional: true},
      {:ex_json_schema, "~> 0.9.1", optional: true},
      {:plug, "~> 1.14.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
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
      files: ~w(lib mix.exs .formatter.exs README.md CHANGELOG.md LICENSE config priv)
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
