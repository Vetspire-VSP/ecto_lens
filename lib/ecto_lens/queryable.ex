defmodule EctoLens.Queryable do
  @moduledoc false
  # coveralls-ignore-start

  import Ecto.Query

  defmacro __using__(_opts \\ []) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query

      import unquote(__MODULE__)

      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def base_query, do: from(x in __MODULE__, as: :self)

      @impl unquote(__MODULE__)
      def query(base_query \\ base_query(), filters) do
        Enum.reduce(filters, base_query, fn {field, value}, query ->
          apply_filter(query, field, value)
        end)
      end

      defoverridable query: 1, query: 2, base_query: 0
    end
  end

  @optional_callbacks base_query: 0
  @callback base_query :: Ecto.Queryable.t()
  @callback query(base_query :: Ecto.Queryable.t(), Keyword.t()) :: Ecto.Queryable.t()

  @spec apply_filter(Ecto.Queryable.t(), field :: atom(), value :: any()) :: Ecto.Queryable.t()
  def apply_filter(query, :prefix, value) do
    from(x in query, prefix: ^value)
  end

  def apply_filter(query, :preload, value) do
    from(x in query, preload: ^value)
  end

  def apply_filter(query, :limit, value) do
    from(x in query, limit: ^value)
  end

  def apply_filter(query, :offset, value) do
    from(x in query, offset: ^value)
  end

  def apply_filter(query, :order_by, value) when is_list(value) do
    from(x in query, order_by: ^value)
  end

  def apply_filter(query, :order_by, {direction, value}) do
    from(x in query, order_by: [{^direction, ^value}])
  end

  def apply_filter(query, :order_by, value) do
    from(x in query, order_by: [{:desc, ^value}])
  end

  def apply_filter(query, field, %Regex{} = regex) do
    case_insensitive =
      cond do
        is_list(regex.opts) and :caseless in regex.opts -> true
        is_binary(regex.opts) and String.contains?(regex.opts, "i") -> true
        true -> false
      end

    if case_insensitive do
      from(x in query, where: fragment("? ~* ?", field(x, ^field), ^regex.source))
    else
      from(x in query, where: fragment("? ~ ?", field(x, ^field), ^regex.source))
    end
  end

  def apply_filter(query, field, value) when is_list(value) do
    from(x in query, where: field(x, ^field) in ^value)
  end

  def apply_filter(query, field, value) do
    from(x in query, where: field(x, ^field) == ^value)
  end
end
