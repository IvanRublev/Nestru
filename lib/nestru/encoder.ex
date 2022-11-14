defprotocol Nestru.Encoder do
  @fallback_to_any true

  @doc """
  Returns the fields map from the given struct to be encoded to map recursively.

  It can be used to adapt the keys of the map to target shape.

  The first argument is the encodable struct value adopting the protocol.

  The second argument is the context given to `encode_to_map/2`
  or `encode_to_list_of_maps/2` functions.

  `Nestru` calls this function as the first step of the encoding procedure.

  If the function returns `{:ok, map}`, then encoding continues, and each `map`
  value that is struct is encoded into a map, the same is done recursively for lists,
  and other values are kept as is.

  If the function returns `{:error, message}` tuple, then encoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  To generate the default implementation of the function, add
  the `@derive #{inspect(__MODULE__)}` attribute to the struct.

  The default implementation gathers keys from the struct
  by calling `Map.from_struct/1`.

  ## Examples

      def Supplier do
        # Derive the default implementation
        @derive Nestru.Encoder

        defstruct [:id, :name]
      end

      defmodule FruitBox do
        defstruct [:items]

        # Implement the function returning the map explicitly
        defimpl Nestru.Encoder do
          def gather_fields_from_struct(struct, _context) do
            # Rename the key in the result map
            {:ok, %{elements: &Map.get(struct, :items)}}
          end
        end
      end
  """
  def gather_fields_from_struct(struct, context)
end

defimpl Nestru.Encoder, for: Any do
  defmacro __deriving__(module, _struct, _opts) do
    quote do
      defimpl Nestru.Encoder, for: unquote(module) do
        def gather_fields_from_struct(struct, _context), do: {:ok, Map.from_struct(struct)}
      end
    end
  end

  def gather_fields_from_struct(%module{}, _context) do
    raise "Please, @derive Nestru.Encoder protocol before defstruct/1 call in #{inspect(module)} or defimpl the protocol in the module explicitly to support encoding into map."
  end
end
