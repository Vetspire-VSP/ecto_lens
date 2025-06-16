defmodule Endo.Adapters.Postgres do
  @moduledoc """
  Adapter module implementing the ability for Endo to reflect upon any
  Postgres-based Ecto Repo.

  See `Endo` documentation for list of features.

  In future, parts of `Endo`'s top level documentation may be moved here, but as
  this is the only supported adapter at the time of writing, this isn't the case.
  """

  @behaviour Endo.Adapter

  alias Endo.Adapters.Postgres.Column
  alias Endo.Adapters.Postgres.Index
  alias Endo.Adapters.Postgres.Metadata
  alias Endo.Adapters.Postgres.PgClass
  alias Endo.Adapters.Postgres.PgIndex
  alias Endo.Adapters.Postgres.Size
  alias Endo.Adapters.Postgres.Table
  alias Endo.Adapters.Postgres.TableConstraint
  alias Endo.Column.Postgres.Type

  @spec list_tables(repo :: module(), opts :: Keyword.t()) :: [Table.t()]
  def list_tables(repo, opts \\ []) when is_atom(repo) do
    opts = Keyword.put_new(opts, :prefix, Endo.table_schema())
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

    if Keyword.get(opts, :async, Application.get_env(:endo, :async, true)) do
      tables
      |> Task.async_stream(preload_func, timeout: :timer.minutes(2))
      |> Enum.map(fn {:ok, table} -> table end)
    else
      Enum.map(tables, preload_func)
    end
  end

  @spec to_endo(Table.t(), Keyword.t()) :: Endo.Table.t()
  @spec to_endo(TableConstraint.t(), Keyword.t()) :: Endo.Association.t()
  @spec to_endo(Column.t(), Keyword.t()) :: Endo.Column.t()
  @spec to_endo(Index.t(), Keyword.t()) :: Endo.Index.t()

  def to_endo(%Table{} = table, config) do
    %Endo.Table{
      adapter: __MODULE__,
      schema: table.schema,
      name: table.table_name,
      indexes: Enum.map(table.indexes, &to_endo(&1, config)),
      columns: table.columns |> Enum.map(&to_endo(&1, config)) |> Enum.sort_by(& &1.position),
      schemas: %Endo.Schema.NotLoaded{
        table: table.table_name,
        otp_app: Keyword.get(config, :otp_app)
      },
      associations:
        table.table_constraints
        |> Enum.filter(&(&1.constraint_type == "FOREIGN KEY"))
        |> Enum.map(&to_endo(&1, config)),
      metadata: Metadata.derive!(table)
    }
  end

  def to_endo(%Column{} = column, config) do
    %Endo.Column{
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

  def to_endo(%TableConstraint{} = constraint, config) do
    %Endo.Association{
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

  def to_endo(%Index{} = index, config) do
    metadata = index.pg_index || %PgIndex{}

    %Endo.Index{
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
