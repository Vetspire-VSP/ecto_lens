defmodule EctoLens.Adapters.Postgres.Size do
  @moduledoc false

  import Ecto.Query

  @spec query([{:relname, String.t()}, {:prefix, String.t()}]) :: Ecto.Queryable.t()
  def query(opts) do
    relname = Enum.join([opts[:prefix], opts[:relname]], ".")

    select(
      with_cte("virtual_table", "virtual_table",
        as:
          fragment(
            """
            SELECT
              pg_table_size(?::text::regclass) as table_size,
              pg_size_pretty(pg_table_size(?::text::regclass)) as table_size_pretty,
              pg_relation_size(?::text::regclass) as relation_size,
              pg_size_pretty(pg_relation_size(?::text::regclass)) as relation_size_pretty,
              pg_indexes_size(?::text::regclass) as index_size,
              pg_size_pretty(pg_indexes_size(?::text::regclass)) as index_size_pretty,
              pg_total_relation_size(?::text::regclass) -
                pg_relation_size(?::text::regclass) -
                pg_indexes_size(?::text::regclass)
              as toast_size,
              pg_size_pretty(
                pg_total_relation_size(?::text::regclass) -
                pg_relation_size(?::text::regclass) -
                pg_indexes_size(?::text::regclass)
              ) as toast_size_pretty
            """,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname,
            ^relname
          )
      ),
      [virtual_table],
      %{
        table_size: virtual_table.table_size,
        relation_size: virtual_table.relation_size,
        toast_size: virtual_table.toast_size,
        index_size: virtual_table.index_size,
        table_size_pretty: virtual_table.table_size_pretty,
        relation_size_pretty: virtual_table.relation_size_pretty,
        toast_size_pretty: virtual_table.toast_size_pretty,
        index_size_pretty: virtual_table.index_size_pretty
      }
    )
  end
end
