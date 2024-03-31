defmodule Nestru.MixProject do
  use Mix.Project

  @version "1.0.1"
  @repo_url "https://github.com/IvanRublev/Nestru"

  def project do
    [
      app: :nestru,
      version: @version,
      elixir: ">= 1.11.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Tools
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),

      # Docs
      name: "Nestru",
      docs: [
        main: "Nestru",
        source_url: @repo_url,
        source_ref: "v#{@version}"
      ],

      # Package
      package: package(),
      description: "A library to serialize between maps and nested structs"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Development and test dependencies
      {:ex_check, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13.4", only: :test, runtime: false},
      {:mix_test_watch, "~> 1.0", only: :test, runtime: false},
      # Documentation dependencies compatible with Elixir 1.11.0
      {:ex_doc, "0.25.1", only: :docs, runtime: false},
      {:nimble_parsec, "1.1.0", only: :docs, runtime: false}
    ]
  end

  defp cli_env do
    [
      # Run mix test.watch in `:test` env.
      "test.watch": :test,

      # Always run Coveralls Mix tasks in `:test` env.
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test,
      "coveralls.travis": :test,

      # Use a custom env for docs.
      docs: :docs
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
