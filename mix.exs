defmodule Retry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :retry,
      name: "retry",
      description:
        "Simple Elixir macros for linear retry, exponential backoff and wait with composable delays.",
      version: "0.19.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
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

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Safwan Kamarrudin"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/safwank/ElixirRetry"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/safwank/ElixirRetry",
      source_ref: "master"
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
    ]
  end
end
