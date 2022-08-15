defmodule OrderNonNegativeTotal do
  @moduledoc false

  defstruct [:max_total]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      {:ok,
       if map.max_total > 0 do
         %{}
       end}
    end
  end

  defimpl Nestru.Encoder do
    def encode_to_map(struct) do
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
