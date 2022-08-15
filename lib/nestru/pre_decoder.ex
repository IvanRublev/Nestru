defprotocol Nestru.PreDecoder do
  @fallback_to_any true

  @doc """
  Returns a map to be decoded into the struct adopting the protocol.

  `Nestru` calls this function as the first step of the decoding procedure.
  Usefult to adapt the keys of the map to match the field names
  of the target struct.

  The first argument is an empty struct value adopting the protocol.

  The second argument is the context value given to the `Nestru.decode_from_map/3` function call.

  The third argument is a map given to the `Nestru.decode_from_map/3` function call.

  If the function returns `{:ok, map}` then the `map` will be decoded into the struct.

  If the function returns `{:error, message}` tuple, then decoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  The default implementation returns the input map unmodified.

  ## Examples

      defmodule FruitBox do
        @derive Nestru.Decoder

        defstruct [:items]

        defimpl Nestru.PreDecoder do
          # Put the key into the map to be decoded later
          def gather_fields_map(_value, _context, map) do
            {:ok, Map.put(map, :items, Map.get(map, "elements"))}
          end
        end
      end

      def FruitEnergy do
        # Keys map can be given with deriving the protocol.
        # The following will make a function copying the value
        # of the "energy_value" key with the "value" key in the map.
        @derive {Nestru.PreDecoder, %{"energy_value" => :value}}

        @derive Nestru.Decoder

        defstruct [:value]
      end
  """
  def gather_fields_map(value, context, map)
end

defimpl Nestru.PreDecoder, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    opts =
      cond do
        opts == [] ->
          %{}

        is_map(opts) ->
          opts

        true ->
          raise "Nestru.PreDecoder protocol should be derived with fields copying map."
      end

    fields_map = Macro.escape(opts)

    quote do
      defimpl Nestru.PreDecoder, for: unquote(module) do
        def gather_fields_map(_value, _context, map) do
          {:ok,
           Enum.reduce(unquote(fields_map), map, fn {from, to}, map ->
             Map.put(map, to, Nestru.get(map, from))
           end)}
        end
      end
    end
  end

  def gather_fields_map(_value, _context, map), do: {:ok, map}
end
