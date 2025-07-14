defmodule EctoLens.Metadata do
  @moduledoc "Utility module for surfacing adapter specific metadata"

  defmodule NotLoaded do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct []
  end

  defmodule NotAvailable do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [:table, :adapter, :message]
  end

  defmodule Postgres do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct [
      :replica_identity,
      :kind,
      :has_triggers,
      :is_populated,
      :is_partitioned,
      :pg_class,
      :table_size,
      :relation_size,
      :index_size,
      :toast_size,
      :table_size_pretty,
      :relation_size_pretty,
      :index_size_pretty,
      :toast_size_pretty
    ]
  end
end
