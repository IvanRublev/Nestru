defmodule OrderWrongAdoption do
  @moduledoc false

  defstruct [:id]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      case value.id do
        1 -> :nan
        2 -> :error
        3 -> {:ok, :nan}
      end
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, _context) do
      case struct.id do
        1 -> :nan
        2 -> :error
        3 -> {:ok, :nan}
      end
    end
  end
end
