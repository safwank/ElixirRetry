defmodule Retry.Mixfile do
  use Mix.Project

  def project do
    [
      app: :retry,
      name: "elixir_retry",
      description: "Simple Elixir macros for linear retries and exponential backoffs.",
      version: "0.1.0",
      elixir: "~> 1.1",
      source_url: "https://github.com/safwank/ElixirRetry",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end

  defp package do
    [
      maintainers: ["Safwan Kamarrudin"],
      licenses: ["Apache 2.0"],
      links: %{github: "https://github.com/safwank/ElixirRetry"}
    ]
  end
end
