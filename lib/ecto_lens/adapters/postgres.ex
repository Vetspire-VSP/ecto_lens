defmodule EctoLens.Adapters.Postgres do
  @moduledoc """
  Adapter module implementing the ability for EctoLens to reflect upon any
  Postgres-based Ecto Repo.

  See `EctoLens` documentation for list of features.

  In future, parts of `EctoLens`'s top level documentation may be moved here, but as
  this is the only supported adapter at the time of writing, this isn't the case.
  """

  @behaviour EctoLens.Adapter

  alias EctoLens.Adapters.Postgres.Column
  alias EctoLens.Adapters.Postgres.Index
  alias EctoLens.Adapters.Postgres.Metadata
  alias EctoLens.Adapters.Postgres.PgClass
  alias EctoLens.Adapters.Postgres.PgIndex
  alias EctoLens.Adapters.Postgres.Size
  alias EctoLens.Adapters.Postgres.Table
  alias EctoLens.Adapters.Postgres.TableConstraint
  alias EctoLens.Column.Postgres.Type

  @spec list_tables(repo :: module(), opts :: Keyword.t()) :: [Table.t()]
  def list_tables(repo, opts \\ []) when is_atom(repo) do
    opts = Keyword.put_new(opts, :prefix, EctoLens.table_schema())
    preloads = [:columns, table_constraints: [:key_column_usage, :constraint_column_usage]]

    derive_preloads = fn %Table{table_name: name} = table ->
      indexes = PgClass.query(collate_indexes: true, relname: name)
      metadata = PgClass.query(relname: name, relkind: ~w(r t m f p))
      size = Size.query(relname: name, prefix: opts[:prefix])

      %Table{
        table
        | schema: opts[:prefix],
          size: repo.one(size),
          pg_class: repo.one(metadata),
          indexes: repo.all(indexes)
      }
    end

    tables =
      opts
      |> Keyword.delete(:async)
      |> Table.query()
      |> repo.all(timeout: :timer.minutes(2))

    preload_func = fn %Table{} = table ->
      table |> repo.preload(preloads) |> derive_preloads.()
    end

    if Keyword.get(opts, :async, Application.get_env(:ecto_lens, :async, true)) do
      tables
      |> Task.async_stream(preload_func, timeout: :timer.minutes(2))
      |> Enum.map(fn {:ok, table} -> table end)
    else
      Enum.map(tables, preload_func)
    end
  end

  @spec to_ecto_lens(Table.t(), Keyword.t()) :: EctoLens.Table.t()
  @spec to_ecto_lens(TableConstraint.t(), Keyword.t()) :: EctoLens.Association.t()
  @spec to_ecto_lens(Column.t(), Keyword.t()) :: EctoLens.Column.t()
  @spec to_ecto_lens(Index.t(), Keyword.t()) :: EctoLens.Index.t()

  def to_ecto_lens(%Table{} = table, config) do
    %EctoLens.Table{
      adapter: __MODULE__,
      schema: table.schema,
      name: table.table_name,
      indexes: Enum.map(table.indexes, &to_ecto_lens(&1, config)),
      columns:
        table.columns |> Enum.map(&to_ecto_lens(&1, config)) |> Enum.sort_by(& &1.position),
      schemas: %EctoLens.Schema.NotLoaded{
        table: table.table_name,
        otp_app: Keyword.get(config, :otp_app)
      },
      associations:
        table.table_constraints
        |> Enum.filter(&(&1.constraint_type == "FOREIGN KEY"))
        |> Enum.map(&to_ecto_lens(&1, config)),
      metadata: Metadata.derive!(table)
    }
  end

  def to_ecto_lens(%Column{} = column, config) do
    %EctoLens.Column{
      adapter: __MODULE__,
      database: config[:database],
      otp_app: config[:otp_app],
      repo: config[:repo],
      name: column.column_name,
      table_name: column.table_name,
      position: column.ordinal_position,
      default_value: column.column_default,
      type: column.udt_name,
      is_nullable: column.is_nullable == :yes,
      type_metadata: Type.Metadata.derive!(column)
    }
  end

  def to_ecto_lens(%TableConstraint{} = constraint, config) do
    %EctoLens.Association{
      adapter: __MODULE__,
      database: config[:database],
      otp_app: config[:otp_app],
      repo: config[:repo],
      name: constraint.constraint_name,
      type: constraint.constraint_column_usage.table_name,
      from_table_name: constraint.key_column_usage.table_name,
      to_table_name: constraint.constraint_column_usage.table_name,
      from_column_name: constraint.key_column_usage.column_name,
      to_column_name: constraint.constraint_column_usage.column_name
    }
  end

  def to_ecto_lens(%Index{} = index, config) do
    metadata = index.pg_index || %PgIndex{}

    %EctoLens.Index{
      adapter: __MODULE__,
      database: config[:database],
      otp_app: config[:otp_app],
      repo: config[:repo],
      name: index.name,
      columns: index.columns,
      is_primary: metadata.indisprimary,
      is_unique: metadata.indisunique
    }
  end
end
