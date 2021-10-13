defmodule OrderWrongItemFunction do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      if Map.has_key?(map, :only_message_in_error) do
        {:ok, %{id: fn _ -> {:error, %{message: nil}} end}}
      else
        {:ok, %{id: fn _ -> 16 end}}
      end
    end
  end
end
