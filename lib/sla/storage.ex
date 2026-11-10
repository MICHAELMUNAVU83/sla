defmodule Sla.Storage do
  @moduledoc "Storage boundary for local development and S3-compatible production storage."

  def adapter, do: Application.fetch_env!(:sla, :storage) |> Keyword.fetch!(:adapter)
  def put(key, body, opts \\ []), do: adapter().put(key, body, storage_opts(opts))
  def url(key, opts \\ []), do: adapter().url(key, storage_opts(opts))
  def read(key, opts \\ []), do: adapter().read(key, storage_opts(opts))
  def delete(key, opts \\ []), do: adapter().delete(key, storage_opts(opts))

  def direct_upload?,
    do: Code.ensure_loaded?(adapter()) and function_exported?(adapter(), :presign_upload, 2)

  def presign_upload(entry, socket), do: adapter().presign_upload(entry, socket)

  defp storage_opts(opts), do: Keyword.merge(Application.fetch_env!(:sla, :storage), opts)
end
