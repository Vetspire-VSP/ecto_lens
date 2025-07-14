defmodule EctoLens.Adapters.Postgres.PgAttribute do
  @moduledoc false

  use Ecto.Schema
  use EctoLens.Queryable

  @type t :: %__MODULE__{}

  @foreign_key_type :string
  @primary_key false
  schema "pg_attribute" do
    # (references pg_class.oid)
    field(:attrelid, :id)
    field(:attname, :string)
    # (references pg_type.oid)
    field(:atttypid, :id)
    field(:attstattarget, :integer)
    field(:attlen, :integer)
    field(:attnum, :integer)
    field(:attndims, :integer)
    field(:attcacheoff, :integer)
    field(:atttypmod, :integer)
    field(:attbyval, :boolean)
    field(:attalign, :string)
    field(:attstorage, :string)
    field(:attcompression, :string)
    field(:attnotnull, :boolean)
    field(:atthasdef, :boolean)
    field(:atthasmissing, :boolean)
    field(:attidentity, :string)
    field(:attgenerated, :string)
    field(:attisdropped, :boolean)
    field(:attislocal, :boolean)
    field(:attinhcount, :integer)
    # (references pg_collation.oid)
    field(:attcollation, :id)
    field(:attoptions, {:array, :string})
    field(:attfdwoptions, {:array, :string})
  end
end
