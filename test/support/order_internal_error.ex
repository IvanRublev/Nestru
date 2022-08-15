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
    def encode_to_map(_struct) do
      {:error, "internal error"}
    end
  end
end
