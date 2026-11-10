defmodule Sla.AI.Provider do
  @moduledoc false
  @callback generate(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
