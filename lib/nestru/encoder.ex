defprotocol Nestru.Encoder do
  @fallback_to_any true

  @doc """
  Returns the fields map from the encodable struct to be merged to the return map.

  The implementation for `Any` makes a map by calling `Map.from_struct/1`.

  This function is a good place for encoding struct type into the map
  for further decoding.

  The first argument is the encodable struct value adopting the protocol.

  If the function returns `{:ok, map}` then encoding continues, and the `map`
  is inserted into the encoded map.

  If the function returns `{:error, message}` tuple, then encoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.
  """
  def encode_to_map(value)
end

defimpl Nestru.Encoder, for: Any do
  defmacro __deriving__(module, _struct, _opts) do
    quote do
      defimpl Nestru.Encoder, for: unquote(module) do
        def encode_to_map(value), do: {:ok, Map.from_struct(value)}
      end
    end
  end

  def encode_to_map(%module{}) do
    raise "Please, @derive Nestru.Encoder protocol before defstruct/1 call in #{inspect(module)} or defimpl the protocol in the module explicitly to support encoding into map."
  end

  def encode_to_map(value) do
    {:ok, value}
  end
end
