defmodule EctoLens.Adapters.Postgres.Column do
  @moduledoc false

  use Ecto.Schema
  use EctoLens.Queryable

  alias EctoLens.Adapters.Postgres.Table

  @type t :: %__MODULE__{}

  @schema_prefix "information_schema"
  @primary_key false
  @foreign_key_type :string
  schema "columns" do
    field(:column_name, :string, primary_key: true)

    belongs_to(:table, Table,
      foreign_key: :table_name,
      references: :table_name,
      primary_key: true
    )

    field(:column_default, :string)
    field(:data_type, :string)
    field(:datetime_precision, :integer)
    field(:maximum_cardinality, :integer)
    field(:interval_precision, :integer)
    field(:interval_type, :string)

    field(:numeric_precision, :integer)
    field(:numeric_precision_radix, :integer)
    field(:numeric_scale, :integer)
    field(:ordinal_position, :integer)

    field(:character_maximum_length, :integer)
    field(:character_octet_length, :integer)
    field(:character_set_catalog, :string)
    field(:character_set_name, :string)
    field(:character_set_schema, :string)

    field(:collation_catalog, :string)
    field(:collation_name, :string)
    field(:collation_schema, :string)

    field(:domain_catalog, :string)
    field(:domain_name, :string)
    field(:domain_schema, :string)

    field(:dtd_identifier, :string)

    field(:scope_catalog, :string)
    field(:scope_name, :string)
    field(:scope_schema, :string)

    field(:table_catalog, :string)
    field(:table_schema, :string)

    field(:udt_catalog, :string)
    field(:udt_name, :string)
    field(:udt_schema, :string)

    field(:identity_generation, :string)
    field(:identity_start, :string)
    field(:identity_increment, :string)
    field(:identity_maximum, :string)
    field(:identity_minimum, :string)

    field(:generation_expression, :string)

    field(:is_generated, :string)
    field(:is_updatable, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:is_nullable, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:is_self_referencing, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:is_identity, Ecto.Enum, values: [yes: "YES", no: "NO"])
    field(:identity_cycle, Ecto.Enum, values: [yes: "YES", no: "NO"])
  end

  @impl EctoLens.Queryable
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:subquery, true}, query ->
        from([self: self] in query, where: parent_as(:self).table_name == self.table_name)

      {field, value}, query ->
        apply_filter(query, field, value)
    end)
  end
end
