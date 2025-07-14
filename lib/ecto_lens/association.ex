defmodule EctoLens.Association do
  @moduledoc "Association metadata for a given table's associations"
  @type t :: %__MODULE__{}
  defstruct [
    :adapter,
    :name,
    :type,
    :from_table_name,
    :to_table_name,
    :from_column_name,
    :to_column_name,
    :repo,
    :otp_app,
    :database
  ]
end
