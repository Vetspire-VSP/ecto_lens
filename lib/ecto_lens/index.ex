defmodule EctoLens.Index do
  @moduledoc "Index metadata for a given table's indexes"

  alias EctoLens.Utils.ETS

  defmodule NotLoaded do
    @moduledoc false
    @type t :: %__MODULE__{}
    defstruct []
  end

  @type t :: %__MODULE__{}
  @default_load_timeout :timer.seconds(15)

  defstruct [
    :adapter,
    :name,
    :repo,
    :otp_app,
    :database,
    is_primary: false,
    is_unique: false,
    columns: []
  ]

  @doc """
  Tries to load a given `EctoLens.Column.t()`'s `indexes` field.

  Can take multiple inputs:
    - A single `EctoLens.Table.t()`
    - A list of `EctoLens.Table.t()`s
    - A single `EctoLens.Column.t()`
    - A list of `EctoLens.Column.t()`s

  Please note that given `EctoLens.Column.t()` structs, additional `EctoLens` lookups are necessary. Thus, for the best
  performance, it will be more optimal to pass in `EctoLens.Table.t()` structs if possible.

  Will raise an error if given a mixed list of `EctoLens.Column.t()`s and `EctoLens.Table.t()`s.

  Takes an optional `Keyword.t()` of options:
    - `timeout` which is an integer representing the number of milliseconds before which loading should be aborted.
      This is only really a consideration for loading indexes across multiple tables and does not apply otherwise.
      Defaults to `:timer.seconds(15)`.

  """
  @spec load(EctoLens.Table.t() | EctoLens.Column.t(), opts :: Keyword.t()) ::
          EctoLens.Table.t() | EctoLens.Column.t()
  @spec load([EctoLens.Table.t() | EctoLens.Column.t()], opts :: Keyword.t()) :: [
          EctoLens.Table.t() | EctoLens.Column.t()
        ]
  def load([], _opts) do
    []
  end

  def load([%EctoLens.Column{repo: repo} | _rest] = columns, opts) do
    unless Enum.all?(columns, &is_struct(&1, EctoLens.Column)) do
      columns = inspect(columns)

      raise ArgumentError,
        message: "All entities in the list must be of type `EctoLens.Column.t()`. Got: #{columns}"
    end

    tables =
      columns
      |> Enum.map(& &1.table_name)
      |> Enum.uniq()
      |> then(&EctoLens.list_tables(repo, table_name: &1))
      |> load(opts)
      |> Map.new(&{&1.name, &1})

    Enum.map(columns, fn
      column when is_struct(column.indexes, NotLoaded) ->
        Enum.find(tables[column.table_name].columns, &(&1.name == column.name))

      column ->
        column
    end)
  end

  def load(%EctoLens.Column{table_name: table, repo: repo, indexes: %NotLoaded{}} = column, opts) do
    %EctoLens.Table{columns: columns} =
      repo
      |> EctoLens.get_table(table)
      |> load(opts)

    Enum.find(columns, &(&1.name == column.name))
  end

  def load(%EctoLens.Column{} = column, _opts) do
    column
  end

  def load([%EctoLens.Table{} | _rest] = tables, opts) do
    unless Enum.all?(tables, &is_struct(&1, EctoLens.Table)) do
      tables = inspect(tables)

      raise ArgumentError,
        message: "All entities in list must be of type `EctoLens.Table.t()`. Got: #{tables}"
    end

    timeout = Keyword.get(opts, :timeout, @default_load_timeout)

    tables
    |> Task.async_stream(&load(&1, opts), ordered: true, max_timeout: timeout)
    |> Enum.map(fn {:ok, resp} -> resp end)
  end

  def load(%EctoLens.Table{columns: columns, indexes: indexes} = table, _opts) do
    index_bag = ETS.new(:duplicate_bag)

    for index <- indexes, column <- index.columns do
      ETS.put(index_bag, column, index)
    end

    %EctoLens.Table{table | columns: Enum.map(columns, &do_load(&1, index_bag))}
  end

  defp do_load(%EctoLens.Column{indexes: %NotLoaded{}} = column, index_bag) do
    %EctoLens.Column{column | indexes: ETS.get(index_bag, column.name, [])}
  end

  # coveralls-ignore-start
  defp do_load(%EctoLens.Column{} = column, _index_bag) do
    column
  end
end
