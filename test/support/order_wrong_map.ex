defmodule OrderWrongMap do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id, :max_total]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      case map.id do
        "1" -> {:ok, %{max_totalll: map.max_total / 100.0}}
        "2" -> {:ok, %{max_total: :hello}}
        "3" -> {:ok, %{max_total: "hello"}}
      end
    end
  end
end
