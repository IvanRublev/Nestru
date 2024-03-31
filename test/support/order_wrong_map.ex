defmodule OrderWrongMap do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id, :max_total]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      case value.id do
        "1" -> {:ok, %{max_totalll: value.max_total / 100.0}}
        "2" -> {:ok, %{max_total: :hello}}
        "3" -> {:ok, %{max_total: "hello"}}
      end
    end
  end
end
