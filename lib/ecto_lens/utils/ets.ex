defmodule EctoLens.Utils.ETS do
  @moduledoc """
  Exposes functions for some basic ETS operations.
  https://www.erlang.org/doc/man/ets.html
  # coveralls-ignore-start
  """

  @type type :: :set | :ordered_set | :bag | :duplicate_bag

  @spec new(type :: type()) :: :ets.tab()
  def new(type \\ :set) do
    :ets.new(__MODULE__, [type, :public, write_concurrency: true, read_concurrency: true])
  end

  @spec put(:ets.tab(), term(), term()) :: :ets.tab()
  def put(table, key, value) do
    :ets.insert(table, {key, value})
    table
  end

  @spec get(:ets.tab(), term(), term()) :: term()
  def get(table, key, default \\ nil) do
    type = type(table)

    case :ets.lookup(table, key) do
      [] ->
        default

      [{^key, value}] when type == :set ->
        value

      [{^key, _value} | _rest] = values when type == :duplicate_bag ->
        Enum.map(values, &elem(&1, 1))
    end
  end

  @spec has_key?(:ets.tab(), term()) :: boolean()
  def has_key?(table, key) do
    :ets.member(table, key)
  end

  @spec from_list(list()) :: :ets.tab()
  def from_list(enum) do
    table = new()
    for {key, value} <- enum, do: put(table, key, value)
    table
  end

  @spec to_list(:ets.tab()) :: list()
  def to_list(table) do
    raw_list = :ets.tab2list(table)

    case type(table) do
      :duplicate_bag ->
        raw_list |> Enum.group_by(&elem(&1, 0), &elem(&1, 1)) |> Enum.to_list()

      _otherwise ->
        raw_list
    end
  end

  @spec type(:ets.tab()) :: type()
  defp type(table), do: :ets.info(table, :type)
end
