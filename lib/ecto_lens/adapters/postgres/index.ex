defmodule EctoLens.Adapters.Postgres.Index do
  @moduledoc false
  @type t :: %__MODULE__{}
  defstruct [:columns, :name, :pg_index]
end
