defmodule ExMarshal.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_marshal,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps,
     description: description,
     package: package]
  end

  def application, do: []

  defp description do
    "Ruby Marshal format implemented in Elixir."
  end

  defp package do
    [files: ["lib", "mix.exs", "mix.lock", "README.md", "LICENSE"],
     contributors: ["Damir Gaynetdinov"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/gaynetdinov/ex_marshal"}]
  end

  defp deps do
    [{:decimal, "~> 1.1.0"}]
  end
end
