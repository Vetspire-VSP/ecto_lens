defmodule EndoTest do
  use ExUnit.Case

  setup_all do
    Logger.configure(level: :error)
    {:ok, find: fn tables, name -> Enum.find(tables, &(&1.name == name)) end}
  end

  describe "table_schema/0" do
    test "returns specified table schema" do
      # If configured, return the configured value
      assert :ok = Application.put_env(:endo, :table_schema, "a_custom_schema_prefix")
      assert "a_custom_schema_prefix" = Endo.table_schema()

      # TODO: Otherwise fall back to "public" which is the default in Postgres at least --
      #       might need to investigate how we go about supporting this for future adapters.
      assert :ok = Application.delete_env(:endo, :table_schema)
      assert "public" = Endo.table_schema()
    end
  end

  describe "list_tables/2" do
    test "returns error when given non-ecto repo" do
      assert_raise(
        ArgumentError,
        "Expected a module that `use`-es `Ecto.Repo`, got: `Enum`",
        fn -> Endo.list_tables(Enum) end
      )
    end

    test "returns error when given ecto repo, but unsupported adapter" do
      assert_raise(
        ArgumentError,
        """
        Unsupported adapter given. Supported adapters are currently: [Ecto.Adapters.Postgres].
        Given: :test_adapter
        """,
        fn -> Endo.list_tables(Test.BadRepo) end
      )
    end
  end

  describe "get_table/3" do
    test "returns error when given non-ecto repo" do
      assert_raise(
        ArgumentError,
        "Expected a module that `use`-es `Ecto.Repo`, got: `Enum`",
        fn -> Endo.get_table(Enum, "users") end
      )
    end

    test "returns error when given ecto repo, but unsupported adapter" do
      assert_raise(
        ArgumentError,
        """
        Unsupported adapter given. Supported adapters are currently: [Ecto.Adapters.Postgres].
        Given: :test_adapter
        """,
        fn -> Endo.get_table(Test.BadRepo, "users") end
      )
    end
  end

  describe "get_table/3 (Postgres)" do
    test "given valid table name and repo, returns Endo Table" do
      assert %Endo.Table{name: "orgs", schema: "public"} =
               Endo.get_table(Test.Postgres.Repo, "orgs")
    end

    test "given invalid table name, but valid repo, returns nil" do
      assert is_nil(Endo.get_table(Test.Postgres.Repo, "passports"))
    end

    test "returns nothing when querying table belonging to non-default prefix when not specified" do
      assert is_nil(Endo.get_table(Test.Postgres.Repo, "events"))
    end

    test "returns nothing when querying table belonging to incorrectly specified prefix" do
      assert is_nil(Endo.get_table(Test.Postgres.Repo, "events", prefix: "something_random"))
    end

    test "returns table belonging to non-default prefix if specified correctly" do
      assert %Endo.Table{name: "events", schema: "debug"} =
               Endo.get_table(Test.Postgres.Repo, "events", prefix: "debug")
    end

    test "given `async: false` option, derives preloads synchronously and returns table" do
      assert %Endo.Table{name: "orgs", schema: "public"} =
               Endo.get_table(Test.Postgres.Repo, "orgs", async: false)
    end
  end

  describe "list_tables/2 (Postgres)" do
    test "lists tables and metadata when given valid repo", ctx do
      assert tables = Endo.list_tables(Test.Postgres.Repo)

      assert Enum.count(tables) == 5

      assert %Endo.Table{} = schema_migrations = ctx.find.(tables, "schema_migrations")
      assert %Endo.Table{} = orgs = ctx.find.(tables, "orgs")
      assert %Endo.Table{} = _accounts = ctx.find.(tables, "accounts")
      assert %Endo.Table{} = accounts_orgs = ctx.find.(tables, "accounts_orgs")
      assert %Endo.Table{} = repos = ctx.find.(tables, "repos")

      # By default, the standard ecto `schema_migrations` table is created for us and is public. Endo does not
      # filter it by default.
      # It does prove to be a simple table though, so serves us well in tests like so:
      assert Enum.count(schema_migrations.associations) == 0
      assert Enum.count(schema_migrations.indexes) == 1
      assert Enum.count(schema_migrations.columns) == 2

      assert %Endo.Column{name: "version", type: "int8"} =
               ctx.find.(schema_migrations.columns, "version")

      assert %Endo.Column{name: "inserted_at", type: "timestamp"} =
               ctx.find.(schema_migrations.columns, "inserted_at")

      assert %Endo.Index{name: "schema_migrations_pkey"} =
               ctx.find.(schema_migrations.indexes, "schema_migrations_pkey")

      # Likewise, the `orgs` table we create in our migrations is pretty simple:
      assert Enum.count(orgs.associations) == 0
      assert Enum.count(orgs.indexes) == 1
      assert Enum.count(orgs.columns) == 4

      for col <- ["inserted_at", "updated_at", "name", "id"],
          do: refute(is_nil(ctx.find.(orgs.columns, col)))

      # However, `accounts_orgs` is a many-to-many join table, and thus has two associations.
      # Association metadata is also surfaced:
      assert Enum.count(accounts_orgs.associations) == 2

      assert %Endo.Association{
               name: "accounts_orgs_account_id_fkey",
               type: "accounts",
               from_table_name: "accounts_orgs",
               to_table_name: "accounts",
               from_column_name: "account_id",
               to_column_name: "id"
             } = ctx.find.(accounts_orgs.associations, "accounts_orgs_account_id_fkey")

      assert %Endo.Association{
               name: "accounts_orgs_org_id_fkey",
               type: "orgs",
               from_table_name: "accounts_orgs",
               to_table_name: "orgs",
               from_column_name: "org_id",
               to_column_name: "id"
             } = ctx.find.(accounts_orgs.associations, "accounts_orgs_org_id_fkey")

      # Of course, individual tables might represent a many-to-one association. This likewise is
      # surfaced:
      assert Enum.count(repos.associations) == 1

      assert %Endo.Association{
               name: "repos_account_id_fkey",
               type: "accounts",
               from_table_name: "repos",
               to_table_name: "accounts",
               from_column_name: "account_id",
               to_column_name: "id"
             } = ctx.find.(repos.associations, "repos_account_id_fkey")
    end

    test "lists tables and metadata for all tables with column" do
      # Only the `schema_migrations` table has a `version` column
      assert [%Endo.Table{name: "schema_migrations"}] =
               Endo.list_tables(Test.Postgres.Repo, with_column: "version")

      # Whereas all tables has an `inserted_at` column
      assert 5 ==
               Test.Postgres.Repo |> Endo.list_tables(with_column: "inserted_at") |> Enum.count()

      # `schema_migrations` does not have an `updated_at` however
      assert 4 ==
               Test.Postgres.Repo |> Endo.list_tables(with_column: "updated_at") |> Enum.count()
    end

    test "lists tables and metadata for all tables without column", ctx do
      # Only `schema_migrations` has a `version` column, so all other tables are returned
      assert tables = Endo.list_tables(Test.Postgres.Repo, without_column: "version")
      assert Enum.count(tables) == 4
      assert is_nil(ctx.find.(tables, "schema_migrations"))

      # Only `schema_migrations` lacks an `updated_at`
      assert tables = Endo.list_tables(Test.Postgres.Repo, without_column: "updated_at")
      assert Enum.count(tables) == 1
      refute is_nil(ctx.find.(tables, "schema_migrations"))
    end

    test "lists tables and metadata for all tables with and without columns", ctx do
      # Only `repos` has an `account_id` but no `org_id`
      assert tables =
               Endo.list_tables(Test.Postgres.Repo,
                 with_column: "account_id",
                 without_column: "org_id"
               )

      assert Enum.count(tables) == 1
      refute is_nil(ctx.find.(tables, "repos"))
    end

    test "lists tables and metadata for all tables with foreign key constraint", ctx do
      # Two tables are associated with `accounts`
      assert tables =
               Endo.list_tables(Test.Postgres.Repo, with_foreign_key_constraint: "accounts")

      assert Enum.count(tables) == 2
      refute is_nil(ctx.find.(tables, "repos"))
      refute is_nil(ctx.find.(tables, "accounts_orgs"))

      # Only one table is associated with `orgs`
      assert tables = Endo.list_tables(Test.Postgres.Repo, with_foreign_key_constraint: "orgs")
      assert Enum.count(tables) == 1
      refute is_nil(ctx.find.(tables, "accounts_orgs"))
    end

    test "lists tables and metadata for all tables without foreign key constraint", ctx do
      # As `accounts_orgs` and `repos` are associated with `accounts`; that means `accounts`, `orgs`,
      # and `schema_migrations` are _not_ associated with `accounts`
      assert tables =
               Endo.list_tables(Test.Postgres.Repo, without_foreign_key_constraint: "accounts")

      assert Enum.count(tables) == 3
      refute is_nil(ctx.find.(tables, "accounts"))
      refute is_nil(ctx.find.(tables, "orgs"))
      refute is_nil(ctx.find.(tables, "schema_migrations"))
    end

    test "lists tables and metadata for all tables with index", ctx do
      # Tables `accounts`, `orgs`, and `repos` have primary keys called `id`. These are
      # indexed by default.
      assert tables_1 = Endo.list_tables(Test.Postgres.Repo, with_index: "id")
      assert Enum.count(tables_1) == 3

      assert tables_2 = Endo.list_tables(Test.Postgres.Repo, with_column: "id")
      assert Enum.count(tables_2) == 3

      assert Enum.sort(tables_1) == Enum.sort(tables_2)

      # Only one table (`accounts`) in our migrations indexes `updated_at`
      assert tables = Endo.list_tables(Test.Postgres.Repo, with_index: "updated_at")
      refute is_nil(ctx.find.(tables, "accounts"))
    end

    test "lists tables and metadata for all tables with compound index" do
      # `accounts` has an index on `inserted_at`, and `updated_at`
      assert [%Endo.Table{name: "accounts"}] =
               Endo.list_tables(Test.Postgres.Repo,
                 table_name: "accounts",
                 with_index: "inserted_at"
               )

      assert [%Endo.Table{name: "accounts"}] =
               Endo.list_tables(Test.Postgres.Repo,
                 table_name: "accounts",
                 with_index: "updated_at"
               )

      # But it does _not_ have a compound index on both of those, these are two individual indexes
      assert [] =
               Endo.list_tables(Test.Postgres.Repo,
                 table_name: "accounts",
                 with_index: ["inserted_at", "updated_at"]
               )

      # `accounts_orgs` _does_ have a compound index on `account_id x org_id` however
      assert [%Endo.Table{name: "accounts_orgs"}] =
               Endo.list_tables(Test.Postgres.Repo, with_index: ["account_id", "org_id"])

      # Compound index lookup is order sentitive
      assert [] = Endo.list_tables(Test.Postgres.Repo, with_index: ["org_id", "account_id"])

      # And lookups of a single component will not work -- the full index must be given at all times
      assert [] = Endo.list_tables(Test.Postgres.Repo, with_index: "account_id")
    end

    test "lists tables and metadata for all tables without index", ctx do
      # Only `schema_migrations` and `accounts_orgs` do not define an `id` field, and thus by definition
      # these two tables have no indexes on said field
      assert tables = Endo.list_tables(Test.Postgres.Repo, without_index: "id")
      assert Enum.count(tables) == 2
      refute is_nil(ctx.find.(tables, "schema_migrations"))
      refute is_nil(ctx.find.(tables, "accounts_orgs"))

      # No tables defining an `id` field lack an index on `id`
      assert [] = Endo.list_tables(Test.Postgres.Repo, with_column: "id", without_index: "id")

      # Some tables define an `inserted_at` but don't index it however:
      assert tables =
               Endo.list_tables(Test.Postgres.Repo,
                 with_column: "inserted_at",
                 without_index: "inserted_at"
               )

      assert Enum.count(tables) == 4
      refute is_nil(ctx.find.(tables, "schema_migrations"))
      refute is_nil(ctx.find.(tables, "accounts_orgs"))
      refute is_nil(ctx.find.(tables, "orgs"))
      refute is_nil(ctx.find.(tables, "repos"))
    end

    test "lists tables and metadata for all tables without compound index", ctx do
      # Only `accounts_orgs` defines a compound index on `account_id` x `org_id`, thus all other
      # tables should be returned when this is excluded
      assert tables =
               Endo.list_tables(Test.Postgres.Repo, without_index: ["account_id", "org_id"])

      assert Enum.count(tables) == 4
      assert is_nil(ctx.find.(tables, "accounts_orgs"))
    end

    test "lists tables and metadata with given table name filters", ctx do
      assert [] = Endo.list_tables(Test.Postgres.Repo, table_name: "doesn't exist")

      assert [%Endo.Table{name: "accounts"}] =
               Endo.list_tables(Test.Postgres.Repo, table_name: "accounts")

      assert tables =
               Endo.list_tables(Test.Postgres.Repo, table_name: ["accounts", "random", "orgs"])

      assert is_nil(ctx.find.(tables, "random"))
      refute is_nil(ctx.find.(tables, "accounts"))
      refute is_nil(ctx.find.(tables, "orgs"))
    end

    test "lists tables and metadata with given table name filters (simple regex)" do
      assert [] = Endo.list_tables(Test.Postgres.Repo, table_name: ~r/Accounts/)
      assert tables = Endo.list_tables(Test.Postgres.Repo, table_name: ~r/Accounts/i)

      for table <- tables, do: assert(table.name =~ "accounts")
    end

    test "lists tables and metadata with given column filters (complex regex)" do
      assert tables = Endo.list_tables(Test.Postgres.Repo, with_column: ~r/(^|_)id/)

      for table <- tables do
        assert Enum.any?(table.columns, fn column ->
                 column.name == "id" or column.name =~ "_id"
               end)
      end
    end

    test "lists tables and metadata for all tables having an index covering field", ctx do
      # Table `accounts_orgs` defines a compound index on `account_id` x `org_id`...
      assert tables_indexing_org_id = Endo.list_tables(Test.Postgres.Repo, with_index: "org_id")

      # However `with_index` only works on exact matches and thus won't be returned.
      assert is_nil(ctx.find.(tables_indexing_org_id, "accounts_orgs"))

      # However `with_index_covering` does away with this limitation, and will find tables where a
      # composite index happens to cover the given column
      assert tables_covering_org_id =
               Endo.list_tables(Test.Postgres.Repo, with_index_covering: "org_id")

      refute is_nil(ctx.find.(tables_covering_org_id, "accounts_orgs"))

      # The inverse is also true; `without_index_covering` will find tables where a composite
      # index does not happen to cover the given column, which we know will be false for the
      # next test:
      assert tables_without_index_covering_account_id =
               Endo.list_tables(Test.Postgres.Repo, without_index_covering: "account_id")

      assert is_nil(ctx.find.(tables_without_index_covering_account_id, "accounts_orgs"))
    end

    test "index metadata contains flags `is_unique` and `is_primary`", ctx do
      assert tables = Endo.list_tables(Test.Postgres.Repo)

      assert %Endo.Table{} = accounts = ctx.find.(tables, "accounts")

      # Account IDs are both unique and also the primary key of the table
      assert %{is_primary: true, is_unique: true} =
               Enum.find(accounts.indexes, &(&1.columns == ["id"]))

      # Account emails are unique, but not the primary key of the table
      assert %{is_primary: false, is_unique: true} =
               Enum.find(accounts.indexes, &(&1.columns == ["email"]))

      # Account timestamps are neither unique nor the primary key of the table
      assert %{is_primary: false, is_unique: false} =
               Enum.find(accounts.indexes, &(&1.columns == ["updated_at"]))
    end

    test "size metadata is returned alongside fetching tables" do
      assert tables = Endo.list_tables(Test.Postgres.Repo)

      for table <- tables, size <- [:table_size, :relation_size, :toast_size, :index_size] do
        assert is_integer(Map.get(table.metadata, size))
      end

      for table <- tables,
          size <- [
            :table_size_pretty,
            :relation_size_pretty,
            :toast_size_pretty,
            :index_size_pretty
          ] do
        # Actual values are, of course, dynamic based on the size of the table.
        # Just assert that we get the number of kilobytes or bytes returned and trust that
        # this scales up into the gigabytes and such accordingly.
        value = Map.get(table.metadata, size)
        assert value =~ "bytes" or value =~ "kB"
      end
    end

    test "colum type metadata is returned alongside tables" do
      assert %Endo.Table{columns: columns} = Endo.get_table(Test.Postgres.Repo, "repos")

      assert %Endo.Column{
               type_metadata: %Endo.Column.Postgres.Type.Metadata.Character{
                 character_length: 255,
                 octet_length: 1020
               }
             } = Enum.find(columns, &(&1.name == "description"))

      assert %Endo.Column{
               type_metadata: %Endo.Column.Postgres.Type.Metadata.Numeric{
                 precision: 64,
                 radix: 2,
                 scale: 0
               }
             } = Enum.find(columns, &(&1.name == "id"))

      assert %Endo.Column{
               type_metadata: %Endo.Column.Postgres.Type.Metadata.DateTime{precision: 0}
             } = Enum.find(columns, &(&1.name == "inserted_at"))

      assert %Endo.Column{
               type_metadata: %Endo.Column.Postgres.Type.Metadata.Interval{
                 type: "MINUTE TO SECOND",
                 precision: 6
               }
             } = Enum.find(columns, &(&1.name == "some_interval"))
    end
  end

  describe "load_indexes/1" do
    test "given an empty list, returns empty list" do
      assert [] = Endo.load_indexes([])
    end

    test "given a list that contains data other than Endo Tables, raises" do
      assert_raise(ArgumentError, fn -> Endo.load_indexes([%Endo.Table{}, 123]) end)
    end

    test "given a list that contains data other than Endo Columns, raises" do
      assert_raise(ArgumentError, fn -> Endo.load_indexes([%Endo.Column{}, 123]) end)
    end

    test "given a list of tables, fetches all indexes for each column", ctx do
      raw_tables = Endo.list_tables(Test.Postgres.Repo)

      for table <- raw_tables, column <- table.columns do
        assert is_struct(column.indexes, Endo.Index.NotLoaded)
      end

      tables = Endo.load_indexes(raw_tables)

      for table <- tables, column <- table.columns do
        assert is_list(column.indexes)
      end

      assert %Endo.Table{} = accounts = ctx.find.(tables, "accounts")

      assert %Endo.Column{
               indexes: [%Endo.Index{is_unique: true, name: "accounts_username_index"}]
             } = Enum.find(accounts.columns, &(&1.name == "username"))

      assert %Endo.Column{indexes: [%Endo.Index{is_unique: true, name: "accounts_email_index"}]} =
               Enum.find(accounts.columns, &(&1.name == "email"))

      assert %Endo.Column{
               indexes: [%Endo.Index{is_unique: false, name: "accounts_inserted_at_index"}]
             } = Enum.find(accounts.columns, &(&1.name == "inserted_at"))

      assert %Endo.Column{
               indexes: [%Endo.Index{is_unique: false, name: "accounts_updated_at_index"}]
             } = Enum.find(accounts.columns, &(&1.name == "updated_at"))

      assert %Endo.Table{} = repos = ctx.find.(tables, "repos")

      assert %Endo.Column{
               indexes: [
                 %Endo.Index{is_unique: true, name: "repos_account_id_name_index"} =
                   repos_account_id_name_index
               ]
             } = Enum.find(repos.columns, &(&1.name == "account_id"))

      assert %Endo.Column{indexes: [^repos_account_id_name_index]} =
               Enum.find(repos.columns, &(&1.name == "name"))

      assert %Endo.Column{indexes: []} = Enum.find(repos.columns, &(&1.name == "some_interval"))
    end

    test "given a single table, returns whether columns are nullable" do
      accounts_orgs = Endo.get_table(Test.Postgres.Repo, "accounts_orgs")

      assert length(accounts_orgs.columns) == 4

      org_id = Enum.find(accounts_orgs.columns, &(&1.name == "org_id"))
      account_id = Enum.find(accounts_orgs.columns, &(&1.name == "account_id"))
      updated_at = Enum.find(accounts_orgs.columns, &(&1.name == "updated_at"))
      inserted_at = Enum.find(accounts_orgs.columns, &(&1.name == "inserted_at"))

      assert org_id.is_nullable
      refute account_id.is_nullable
      refute updated_at.is_nullable
      refute inserted_at.is_nullable
    end

    test "given a single table, fetches all indexes for each column" do
      repos = Endo.get_table(Test.Postgres.Repo, "repos")

      for column <- repos.columns do
        assert is_struct(column.indexes, Endo.Index.NotLoaded)
      end

      repos = Endo.load_indexes(repos)

      for column <- repos.columns do
        assert is_list(column.indexes)
      end

      assert %Endo.Column{
               indexes: [
                 %Endo.Index{is_unique: true, name: "repos_account_id_name_index"} =
                   repos_account_id_name_index
               ]
             } = Enum.find(repos.columns, &(&1.name == "account_id"))

      assert %Endo.Column{indexes: [^repos_account_id_name_index]} =
               Enum.find(repos.columns, &(&1.name == "name"))

      assert %Endo.Column{indexes: []} = Enum.find(repos.columns, &(&1.name == "some_interval"))
    end

    test "given a list of columns, fetches all indexes for each column" do
      repos = Endo.get_table(Test.Postgres.Repo, "repos")

      for column <- repos.columns do
        assert is_struct(column.indexes, Endo.Index.NotLoaded)
      end

      columns = Endo.load_indexes(repos.columns)

      for column <- columns do
        assert is_list(column.indexes)
      end

      assert %Endo.Column{
               indexes: [
                 %Endo.Index{is_unique: true, name: "repos_account_id_name_index"} =
                   repos_account_id_name_index
               ]
             } = Enum.find(columns, &(&1.name == "account_id"))

      assert %Endo.Column{indexes: [^repos_account_id_name_index]} =
               Enum.find(columns, &(&1.name == "name"))

      assert %Endo.Column{indexes: []} = Enum.find(columns, &(&1.name == "some_interval"))
    end

    test "given a single column, fetches all indexes for each column" do
      repos = Endo.get_table(Test.Postgres.Repo, "repos")

      for column <- repos.columns do
        assert is_struct(column.indexes, Endo.Index.NotLoaded)
      end

      assert %Endo.Column{
               indexes: [%Endo.Index{is_unique: true, name: "repos_account_id_name_index"}]
             } = Endo.load_indexes(Enum.find(repos.columns, &(&1.name == "account_id")))
    end

    test "idempotent when called multiple times" do
      repos = Endo.get_table(Test.Postgres.Repo, "repos")

      for column <- repos.columns do
        assert is_struct(column.indexes, Endo.Index.NotLoaded)
      end

      assert loaded_example =
               Endo.load_indexes(Enum.find(repos.columns, &(&1.name == "account_id")))

      assert %Endo.Column{
               indexes: [%Endo.Index{is_unique: true, name: "repos_account_id_name_index"}]
             } = loaded_example

      altered_example = %{loaded_example | indexes: [1, 2, 3, 4, 5, 6]}

      assert %{indexes: [1, 2, 3, 4, 5, 6]} = Endo.load_indexes(altered_example)
      assert [%{indexes: [1, 2, 3, 4, 5, 6]}] = Endo.load_indexes([altered_example])
    end
  end

  describe "load_tables/1" do
    test "given a list that contains data other than Endo Tables, raises" do
      assert_raise(ArgumentError, fn -> Endo.load_schemas([%Endo.Table{}, 123]) end)
    end

    test "given single Endo Table, loads but sets schemas to empty list if it has no schema impl." do
      assert %Endo.Table{schemas: %Endo.Schema.NotLoaded{}} =
               accounts = Endo.get_table(Test.Postgres.Repo, "accounts")

      assert %Endo.Table{schemas: []} = Endo.load_schemas(accounts)
    end

    test "given single Endo Table, loads schemas where they exist" do
      assert %Endo.Table{schemas: %Endo.Schema.NotLoaded{}} =
               orgs = Endo.get_table(Test.Postgres.Repo, "orgs")

      assert %Endo.Table{schemas: [Test.Postgres.Org]} = Endo.load_schemas(orgs)
    end

    test "loads the corresponding Ecto Schemas of all tables in list" do
      assert tables = Endo.list_tables(Test.Postgres.Repo)
      assert Enum.all?(tables, &is_struct(&1.schemas, Endo.Schema.NotLoaded))

      assert tables = Endo.load_schemas(tables)
      refute Enum.all?(tables, &is_struct(&1.schemas, Endo.Schema.NotLoaded))

      # Only the `orgs` table has a corresponding schema, all others are nil
      for table <- tables do
        if table.name == "orgs" do
          assert table.schemas == [Test.Postgres.Org]
        else
          assert table.schemas == []
        end
      end
    end
  end
end
