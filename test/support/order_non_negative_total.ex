defmodule OrderNonNegativeTotal do
  @moduledoc false

  defstruct [:max_total]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      {:ok,
       if value.max_total > 0 do
         %{}
       end}
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, _context) do
      map = Map.from_struct(struct)

      {:ok,
       if map.max_total > 0 do
         map
       else
         nil
       end}
    end
  end
end
