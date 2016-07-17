defmodule Retry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :retry,
      name: "elixir_retry",
      description: "Simple Elixir macros for linear retries and exponential backoffs.",
      version: "0.3.0",
      elixir: "~> 1.1",
      source_url: "https://github.com/safwank/ElixirRetry",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "credo": :test,
        "coveralls.html": :test,
        "commit": :test
      ],
      aliases: [
        "commit": ["credo --strict", "coveralls.html --trace"]
      ],
      default_task: "commit"
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:credo, "~> 0.4.5", only: :test},
      {:excoveralls, "~> 0.5.5", only: :test},
      {:ex_doc, "~> 0.12", only: :dev},
      {:earmark, "~> 0.2.1", only: :dev}
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
