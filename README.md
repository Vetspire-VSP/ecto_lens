# EctoLens

<!--
TODO: fixme
[![hex.pm](https://img.shields.io/hexpm/v/ecto_lens.svg)](https://hex.pm/packages/ecto_lens)
[![hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_lens/)
[![hex.pm](https://img.shields.io/hexpm/dt/ecto_lens.svg)](https://hex.pm/packages/ecto_lens)
[![hex.pm](https://img.shields.io/hexpm/l/ecto_lens.svg)](https://hex.pm/packages/ecto_lens)
-->

EctoLens is a library containing database schema reflection APIs for your applications, as
well as implementations of queryable schemas to facilitate custom database reflection
via Ecto.

See the [official documentation for EctoLens](https://hexdocs.pm/ecto_lens/).

## Installation

This package can be installed by adding `ecto_lens` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_lens, "~> 0.1.0"}
  ]
end
```

## Contributing

We enforce 100% code coverage and quite a strict linting setup for EctoLens.

Please ensure that commits pass CI. You should be able to run both `mix test` and
`mix lint` locally.

See the `mix.exs` to see the breakdown of what these commands do.
