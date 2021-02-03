defmodule Retry.Mixfile do
  use Mix.Project

  @source_url "https://github.com/safwank/ElixirRetry"
  @version "0.14.1"

  def project do
    [
      app: :retry,
      name: "retry",
      description: """
        Simple Elixir macros for linear retry, exponential backoff, and wait
        with composable delays.
      """,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        "coveralls.html": :test,
        commit: :test
      ],
      aliases: [
        commit: ["dialyzer", "credo --strict", "coveralls.html --trace"]
      ],
      default_task: "commit"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4.0", only: :test},
      {:excoveralls, "~> 0.13.0", only: :test},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
    ]
  end

  defp package do
    [
      maintainers: ["Safwan Kamarrudin"],
      licenses: ["Apache-2.0"],
      links: %{GitHub: @source_url}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}",
      main: "readme"
    ]
  end
end
