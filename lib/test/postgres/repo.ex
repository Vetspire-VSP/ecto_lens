if Mix.env() == :test do
  defmodule Test.Postgres.Repo do
    @moduledoc false
    use Ecto.Repo,
      otp_app: :ecto_lens,
      adapter: Ecto.Adapters.Postgres
  end
end
