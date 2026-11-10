defmodule Sla.Matters.FileNumber do
  @moduledoc "Transaction-safe file numbering by practice area and calendar year."
  alias Sla.Repo

  @codes %{
    "real_estate" => "RE",
    "banking_finance" => "BF",
    "dispute_resolution" => "DR",
    "corporate_commercial" => "CC"
  }

  def next(practice_area, %Date{year: year}) when is_map_key(@codes, practice_area) do
    sql = """
    INSERT INTO matter_sequences (practice_area, year, last_number)
    VALUES ($1, $2, 1)
    ON CONFLICT (practice_area, year)
    DO UPDATE SET last_number = matter_sequences.last_number + 1
    RETURNING last_number
    """

    {:ok, %{rows: [[number]]}} = Repo.query(sql, [practice_area, year])

    "SLA/#{Map.fetch!(@codes, practice_area)}/#{year}/#{number |> Integer.to_string() |> String.pad_leading(4, "0")}"
  end
end
