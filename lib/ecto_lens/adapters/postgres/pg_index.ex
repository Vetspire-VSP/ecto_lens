defmodule EctoLens.Adapters.Postgres.PgIndex do
  @moduledoc false

  use Ecto.Schema
  use EctoLens.Queryable

  @type t :: %__MODULE__{}

  @foreign_key_type :string
  @primary_key false
  schema "pg_index" do
    # (references pg_class.oid)
    field(:indexrelid, :id)
    # oid (references pg_class.oid)
    field(:indrelid, :id)
    field(:indnatts, :integer)
    field(:indnkeyatts, :integer)
    field(:indisunique, :boolean)
    field(:indisprimary, :boolean)
    field(:indisexclusion, :boolean)
    field(:indimmediate, :boolean)
    field(:indisclustered, :boolean)
    field(:indisvalid, :boolean)
    field(:indcheckxmin, :boolean)
    field(:indisready, :boolean)
    field(:indislive, :boolean)
    field(:indisreplident, :boolean)

    # TODO: these types aren't supported by Ecto out of the box
    #       but I'm unsure if we really need them
    # field :indkey int2vector (references pg_attribute.attnum)
    # field :indcollation oidvector (references pg_collation.oid)
    # field :indclass oidvector (references pg_opclass.oid)
    # field :indoption int2vector
    # field :indexprs pg_node_tree
    # field :indpred pg_node_tree
  end
end
