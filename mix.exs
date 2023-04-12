defmodule Retry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :retry,
      name: "retry",
      description:
        "Simple Elixir macros for linear retry, exponential backoff and wait with composable delays.",
      version: "0.18.0",
      elixir: "~> 1.12",
      source_url: "https://github.com/safwank/ElixirRetry",
      docs: [
        extras: ["README.md"],
        source_ref: "master"
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
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
    [applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 1.7.0", only: :test},
      {:excoveralls, "~> 0.16.0", only: :test},
      {:dialyxir, "~> 1.3.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.29.0", only: :dev},
      {:earmark, "~> 1.4.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Safwan Kamarrudin"],
      licenses: ["Apache 2.0"],
      links: %{github: "https://github.com/safwank/ElixirRetry"}
    ]
  end
end
