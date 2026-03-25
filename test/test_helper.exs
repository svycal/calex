if Code.ensure_loaded?(Tz.TimeZoneDatabase) do
  {:ok, _} = Application.ensure_all_started(:tz)
  Application.put_env(:elixir, :time_zone_database, Tz.TimeZoneDatabase)
end

ExUnit.start()
