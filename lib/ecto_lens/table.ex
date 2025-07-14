defmodule EctoLens.Table do
  @moduledoc "Table metadata returned by EctoLens."
  @type t :: %__MODULE__{}
  defstruct [
    :adapter,
    :name,
    :schema,
    columns: [],
    associations: [],
    indexes: [],
    schemas: %EctoLens.Schema.NotLoaded{},
    metadata: %EctoLens.Metadata.NotLoaded{}
  ]
end
