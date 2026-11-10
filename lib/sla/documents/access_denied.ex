defmodule Sla.Documents.AccessDenied do
  defexception message: "document access denied", plug_status: 403
end
