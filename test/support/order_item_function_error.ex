defmodule ErroredItemsBook do
  @moduledoc false

  defstruct [:items]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, _value) do
      {:ok, %{items: &Nestru.decode_from_list(&1, OrderItemFunctionError)}}
    end
  end
end

defmodule OrderItemFunctionError do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, _value) do
      {:ok,
       %{
         id: fn
           "1" -> {:error, "something went wrong"}
           "2" -> {:error, %{message: "another thing went wrong", path: [:some, :subpath]}}
           "3" -> {:error, %{message: "failure message", path: [:some, nil]}}
         end
       }}
    end
  end
end
