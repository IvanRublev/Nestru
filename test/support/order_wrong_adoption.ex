defmodule OrderWrongAdoption do
  @moduledoc false

  defstruct [:id]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      case map.id do
        1 -> :nan
        2 -> :error
        3 -> {:ok, :nan}
      end
    end
  end

  defimpl Nestru.Encoder do
    def encode_to_map(struct) do
      case struct.id do
        1 -> :nan
        2 -> :error
        3 -> {:ok, :nan}
      end
    end
  end
end
