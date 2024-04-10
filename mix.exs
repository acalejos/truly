defmodule Truly.MixProject do
  use Mix.Project

  def project do
    [
      app: :truly,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Create a truth table to consolidate complex boolean conditional logic.",
      source_url: "https://github.com/acalejos/truly",
      homepage_url: "https://github.com/acalejos/truly",
      package: package(),
      docs: docs(),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ],
      name: "Truly"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:earmark, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Andres Alejos"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/acalejos/truly"}
    ]
  end

  defp docs do
    [
      main: "Truly"
    ]
  end
end
