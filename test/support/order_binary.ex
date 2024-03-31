defmodule OrderBinary do
  @moduledoc false

  defstruct [:max_total]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, "max_total: " <> binary_tail) do
      {:ok, %OrderBinary{max_total: String.to_float(binary_tail)}}
    end

    def decode_fields_hint(_empty_struct, _context, "not an order binary struct") do
      {:ok, %Invoice{total_sum: 100}}
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, _context) do
      {:ok, "max_total: #{struct.max_total}"}
    end
  end
end
