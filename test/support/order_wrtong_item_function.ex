defmodule OrderWrongItemFunction do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      if Map.has_key?(value, :only_message_in_error) do
        {:ok, %{id: fn _ -> {:error, %{message: nil}} end}}
      else
        {:ok, %{id: fn _ -> 16 end}}
      end
    end
  end
end
