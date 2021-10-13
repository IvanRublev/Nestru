defmodule ErroredItemsBook do
  @moduledoc false

  defstruct [:items]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, _map) do
      {:ok, %{items: &Nestru.from_list_of_maps(&1, OrderItemFunctionError)}}
    end
  end
end

defmodule OrderItemFunctionError do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, _map) do
      {:ok,
       %{
         id: fn
           "1" -> {:error, "something went wrong"}
           "2" -> {:error, %{message: "another thing went wrong", path: [:some, :subpath]}}
         end
       }}
    end
  end
end
