defmodule EctoLens.Adapter do
  @moduledoc """
  Module defining the `EctoLens.Adapter` behaviour. Valid adapters will allow EctoLens to reflect
  upon a module implementing said adater
  """

  @callback list_tables(repo :: module(), filters :: Keyword.t()) :: [map()]
  @callback to_ecto_lens(data :: map(), opts :: Keyword.t()) ::
              EctoLens.Table.t() | EctoLens.Column.t() | EctoLens.Association.t() | EctoLens.Index.t()
end
