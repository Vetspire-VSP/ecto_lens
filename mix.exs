defmodule Endo.MixProject do
  use Mix.Project

  def project do
    [
      app: :endo,
      version: "0.1.24",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:iex, :mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        lint: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test
      ],
      name: "Endo",
      package: package(),
      description: description(),
      source_url: "https://github.com/vetspire/endo",
      homepage_url: "https://github.com/vetspire/endo",
      docs: [
        main: "Endo"
      ]
    ]
  end

  def application do
    [
      mod: {Endo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp description() do
    """
    Endo is a library containing database schema reflection APIs for your applications, as
    well as implementations of queryable schemas to facilitate custom database reflection
    via Ecto.
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vetspire/endo"}
    ]
  end

  defp deps do
    [
      # Endo's actual dependencies
      {:jason, "~> 1.1"},
      {:ecto, "~> 3.12"},

      # Adapter Dependencies, should be supplied by host app but these
      # are nice to have for tests.
      {:postgrex, "~> 0.19", only: :test},
      {:ecto_sql, "~> 3.11", only: :test},

      # Runtime dependencies for tests / linting
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["coveralls.html --trace --slowest 10"],
      lint: [
        "format --check-formatted --dry-run",
        "credo --strict",
        "compile --warnings-as-errors",
        "dialyzer"
      ]
    ]
  end
end
