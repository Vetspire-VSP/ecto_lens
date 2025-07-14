defmodule EctoLens.Adapters.Postgres.PgClass do
  @moduledoc false

  use Ecto.Schema
  use EctoLens.Queryable

  alias EctoLens.Adapters.Postgres.Index
  alias EctoLens.Adapters.Postgres.PgAttribute
  alias EctoLens.Adapters.Postgres.PgIndex

  alias __MODULE__

  @type t :: %__MODULE__{}

  @foreign_key_type :string
  @primary_key false
  schema "pg_class" do
    field(:oid, :id)
    field(:relname, :string)
    # (references pg_namespace.oid)
    field(:relnamespace, :id)
    # (references pg_type.oid)
    field(:reltype, :id)
    # (references pg_type.oid)
    field(:reloftype, :id)
    # (references pg_authid.oid)
    field(:relowner, :id)
    # (references pg_am.oid)
    field(:relam, :id)
    field(:relfilenode, :id)
    # (references pg_tablespace.oid)
    field(:reltablespace, :id)
    field(:relpages, :integer)
    field(:reltuples, :float)
    field(:relallvisible, :integer)
    # (references pg_class.oid)
    field(:reltoastrelid, :id)
    field(:relhasindex, :boolean)
    field(:relisshared, :boolean)
    field(:relpersistence, :string)
    field(:relkind, :string)
    field(:relnatts, :integer)
    field(:relchecks, :integer)
    field(:relhasrules, :boolean)
    field(:relhastriggers, :boolean)
    field(:relhassubclass, :boolean)
    field(:relrowsecurity, :boolean)
    field(:relforcerowsecurity, :boolean)
    field(:relispopulated, :boolean)
    field(:relreplident, :string)
    field(:relispartition, :boolean)
    # (references pg_class.oid)
    field(:relrewrite, :id)
    field(:relfrozenxid, :id)
    field(:relminmxid, :id)
    field(:reloptions, {:array, :string})
    # field :relacl aclitem[]
    # field :relpartbound pg_node_tree
  end

  @impl EctoLens.Queryable
  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:subquery, true}, query ->
        from([self: self] in query, where: parent_as(:self).table_name == self.relname)

      {:collate_indexes, true}, query ->
        from([self: self] in query,
          where: self.relkind == "r",
          join: pg_index in PgIndex,
          on: self.oid == pg_index.indrelid,
          as: :pg_index,
          join: pg_class in PgClass,
          on: pg_class.oid == pg_index.indexrelid,
          as: :pg_class,
          join: pg_attribute in PgAttribute,
          on: pg_attribute.attrelid == self.oid,
          as: :pg_attribute,
          where: pg_attribute.attnum in pg_index.indkey,
          group_by: [self.oid, self.relname, pg_class.relname, pg_index.indexrelid],
          select: %{
            __struct__: Index,
            name: pg_class.relname,
            columns: fragment("ARRAY_AGG(?)", pg_attribute.attname),
            pg_index: pg_index
          }
        )

      {:having_index, column}, query ->
        columns = (is_list(column) && column) || [column]

        from([self: self, pg_attribute: pg_attribute] in Ecto.Query.exclude(query, :select),
          having: ^columns == fragment("ARRAY_AGG(?)", pg_attribute.attname)
        )

      {:index_covers, column}, query ->
        columns = (is_list(column) && column) || [column]

        from([self: self, pg_attribute: pg_attribute] in Ecto.Query.exclude(query, :select),
          having: fragment("? && ARRAY_AGG(?)", ^columns, pg_attribute.attname)
        )

      {field, value}, query ->
        apply_filter(query, field, value)
    end)
  end
end
