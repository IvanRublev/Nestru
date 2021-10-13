defprotocol Nestru.PreDecoder do
  @fallback_to_any true

  @doc """
  Returns fields map to be decoded into the struct adopting the protocol.

  `Nestru` calls this function as the first step of the decoding procedure.
  Useful when the input map should be changed to match the field names
  of the struct.

  The first argument is an empty struct value adopting the protocol.

  The second argument is the context value given to the `Nestru.from_map/3` function call.

  The third argument is a map given to the `Nestru.from_map/3` function call.

  If the function returns `{:ok, map}` then the `map` will be decoded into the struct.

  If the function returns `{:error, message}` tuple, then decoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  The default implementation returns the input map unmodified.
  """
  def gather_fields_map(value, context, map)
end

defimpl Nestru.PreDecoder, for: Any do
  def gather_fields_map(_value, _context, map), do: {:ok, map}
end
