defmodule Sla.Storage.Local do
  @moduledoc false

  def put(key, body, _opts) do
    root = Application.fetch_env!(:sla, :storage) |> Keyword.fetch!(:root)
    path = Path.join(root, key)
    File.mkdir_p!(Path.dirname(path))
    File.write(path, body)
  end

  def url(key, _opts), do: {:ok, "/uploads/#{URI.encode(key)}"}

  def read(key, opts), do: File.read(Path.join(Keyword.fetch!(opts, :root), key))
  def delete(key, opts), do: File.rm(Path.join(Keyword.fetch!(opts, :root), key))
end
