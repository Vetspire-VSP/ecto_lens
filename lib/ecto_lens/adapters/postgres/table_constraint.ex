defmodule EctoLens.Adapters.Postgres.TableConstraint do
  @moduledoc false

  use Ecto.Schema
  use EctoLens.Queryable

  alias EctoLens.Adapters.Postgres.ConstraintColumnUsage
  alias EctoLens.Adapters.Postgres.KeyColumnUsage
  alias EctoLens.Adapters.Postgres.Table

  @type t :: %__MODULE__{}

  @schema_prefix "information_schema"
  @primary_key false
  @foreign_key_type :string
  schema "table_constraints" do
    belongs_to(:table, Table,
      foreign_key: :table_name,
      references: :table_name,
      primary_key: true
    )

    field(:constraint_name, :string, primary_key: true)

    has_one(:key_column_usage, KeyColumnUsage,
      foreign_key: :constraint_name,
      references: :constraint_name
    )

    has_one(:constraint_column_usage, ConstraintColumnUsage,
      foreign_key: :constraint_name,
      references: :constraint_name
    )

    field(:constraint_catalog, :string)
    field(:constraint_schema, :string)
    field(:constraint_type, :string)

    field(:table_catalog, :string)
    field(:table_schema, :string)

    field(:is_deferrable, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:initially_deferred, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:enforced, Ecto.Enum, values: [yes: "YES", no: "NO"])
  end

  @impl EctoLens.Queryable
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:subquery, true}, query ->
        from([self: self] in query, where: parent_as(:self).table_name == self.table_name)

      {:foreign_table_name, table_name}, query ->
        from([self: self] in query,
          join: constraint_column_usage in assoc(self, :constraint_column_usage),
          where: constraint_column_usage.table_name == ^table_name,
          where: self.constraint_type == "FOREIGN KEY"
        )

      # coveralls-ignore-start
      {field, value}, query ->
        apply_filter(query, field, value)
    end)
  end
end
