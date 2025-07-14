defmodule EctoLens.Column do
  @moduledoc "Column metadata for a given table's columns"

  @type t :: %__MODULE__{}

  defstruct [
    :adapter,
    :name,
    :type,
    :position,
    :is_nullable,
    :type_metadata,
    :default_value,
    :table_name,
    :repo,
    :otp_app,
    :database,
    indexes: %EctoLens.Index.NotLoaded{}
  ]

  defmodule Postgres.Type.Metadata do
    alias EctoLens.Adapters.Postgres

    defmodule Character do
      @moduledoc false
      @type t :: %__MODULE__{}
      defstruct [:character_length, :octet_length]
    end

    defmodule Numeric do
      @moduledoc false
      @type t :: %__MODULE__{}
      defstruct [:precision, :radix, :scale]
    end

    defmodule DateTime do
      @moduledoc false
      @type t :: %__MODULE__{}
      defstruct [:precision]
    end

    defmodule Interval do
      @moduledoc false
      @type t :: %__MODULE__{}
      defstruct [:type, :precision]
    end

    @type t :: Character.t() | Numeric.t() | DateTime.t() | Interval.t()

    @spec derive!(Postgres.Column.t()) :: t() | nil
    def derive!(%Postgres.Column{} = column) when is_integer(column.character_maximum_length) do
      %Character{
        character_length: column.character_maximum_length,
        octet_length: column.character_octet_length
      }
    end

    def derive!(%Postgres.Column{} = column) when is_integer(column.numeric_precision) do
      %Numeric{
        precision: column.numeric_precision,
        radix: column.numeric_precision_radix,
        scale: column.numeric_scale
      }
    end

    def derive!(%Postgres.Column{} = column) when is_binary(column.interval_type) do
      %Interval{type: column.interval_type, precision: column.datetime_precision}
    end

    def derive!(%Postgres.Column{} = column) when is_integer(column.datetime_precision) do
      %DateTime{precision: column.datetime_precision}
    end

    # coveralls-ignore-start
    def derive!(_column) do
      nil
    end
  end
end
