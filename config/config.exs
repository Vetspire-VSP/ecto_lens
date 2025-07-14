import Config

config :ecto_lens, ecto_repos: [Test.Postgres.Repo], table_schema: "public"

config :ecto_lens, Test.Postgres.Repo,
  database: System.fetch_env!("POSTGRES_DB"),
  username: System.fetch_env!("POSTGRES_USER"),
  password: System.fetch_env!("POSTGRES_PASSWORD"),
  hostname: "localhost"
