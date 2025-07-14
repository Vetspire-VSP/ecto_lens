defmodule EctoLens.Schema do
  @moduledoc "Utility module for discovering Ecto Schema implementations for a given EctoLens Table"

  defmodule NotLoaded do
    @moduledoc false

    @type t :: %__MODULE__{}
    defstruct [:table, :otp_app]
  end

  @spec load([EctoLens.Table.t()]) :: [EctoLens.Table.t()]
  @spec load(EctoLens.Table.t()) :: EctoLens.Table.t()

  @doc """
  Given a list of EctoLens Tables, tries to load their schemas in their corresponding OTP App.

  All EctoLens Table structs contain metadata about which OTP app a given Repo belongs to. This information is used
  to load all Elixir modules that `use Ecto.Schema`.

  With this list, we match up any schemas to tables that exist; though it is important to note that not all
  EctoLens Tables will necessarily have a corresponding Ecto Schema module defined for it.

  In this case, the `schemas` key of an EctoLens Table will be an empty list.

  It is also possible for multiple Ecto Schemas to exist for a single underlying database tables, thus, any discovered
  results will be accumulated and returned as a list of modules per EctoLens Table.
  """
  def load([%EctoLens.Table{} | _rest] = ecto_lens_tables) do
    unless Enum.all?(ecto_lens_tables, &is_struct(&1, EctoLens.Table)) do
      ecto_lens_tables = inspect(ecto_lens_tables)

      raise ArgumentError,
        message: "All entities in list must be of type `EctoLens.Table.t()`. Got: #{ecto_lens_tables}"
    end

    {unloaded_ecto_lens_tables, loaded_ecto_lens_tables} =
      Enum.split_with(ecto_lens_tables, &is_struct(&1.schemas, NotLoaded))

    loaded_ecto_lens_tables ++
      (unloaded_ecto_lens_tables
       |> Enum.group_by(& &1.schemas.otp_app)
       |> Enum.flat_map(fn {otp_app, ecto_lens_tables} ->
         app_schemas = app_schemas(otp_app)
         Enum.map(ecto_lens_tables, &do_load(&1, app_schemas))
       end))
  end

  def load(%EctoLens.Table{schemas: %NotLoaded{otp_app: otp_app}} = ecto_lens_table) do
    do_load(ecto_lens_table, app_schemas(otp_app))
  end

  defp do_load(%EctoLens.Table{schemas: %NotLoaded{table: table}} = ecto_lens_table, app_schemas) do
    %EctoLens.Table{ecto_lens_table | schemas: Map.get(app_schemas, table, [])}
  end

  defp app_schemas(otp_app) when is_atom(otp_app) do
    {:ok, modules} = :application.get_key(otp_app, :modules)

    modules
    |> Enum.filter(&function_exported?(&1, :__schema__, 1))
    |> Enum.group_by(& &1.__schema__(:source))
  end
end
