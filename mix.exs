defmodule ExMarshal.Mixfile do
  use Mix.Project

  @source_url "https://github.com/gaynetdinov/ex_marshal"
  @version "0.0.12"

  def project do
    [
      app: :ex_marshal,
      version: @version,
      elixir: "~> 1.1",
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ]
    ]
  end

  def application, do: []

  defp package do
    [
      description: "Ruby Marshal format implemented in Elixir.",
      files: ["lib", "mix.exs", "mix.lock", "README.md", "LICENSE.md"],
      maintainers: ["Damir Gaynetdinov"],
      licenses: ["ISC"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.5 or ~> 2.0"},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
