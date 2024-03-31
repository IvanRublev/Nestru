defmodule OrderInternalError do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, _value) do
      {:error, "internal error"}
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(_struct, _context) do
      {:error, "internal error"}
    end
  end
end
