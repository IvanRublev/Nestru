defmodule OrderInternalError do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, _map) do
      {:error, "internal error"}
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(_struct, _context) do
      {:error, "internal error"}
    end
  end
end
