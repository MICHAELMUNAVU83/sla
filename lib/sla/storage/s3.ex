defmodule Sla.Storage.S3 do
  @moduledoc false

  def put(key, body, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    bucket |> ExAws.S3.put_object(key, body) |> ExAws.request()
  end

  def url(key, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    ExAws.S3.presigned_url(ExAws.Config.new(:s3), :get, bucket, key, expires_in: 900)
  end

  def read(_key, _opts), do: {:error, :remote_storage}

  def delete(key, opts),
    do: opts |> Keyword.fetch!(:bucket) |> ExAws.S3.delete_object(key) |> ExAws.request()

  def presign_upload(entry, socket) do
    opts = Application.fetch_env!(:sla, :storage)
    key = "documents/#{entry.uuid}/#{Path.basename(entry.client_name)}"

    post =
      ExAws.S3.presigned_post(ExAws.Config.new(:s3), Keyword.fetch!(opts, :bucket), key,
        expires_in: 900,
        content_length_range: [1, 50_000_000]
      )

    {:ok, %{uploader: "S3", key: key, url: post.url, fields: post.fields}, socket}
  end
end
