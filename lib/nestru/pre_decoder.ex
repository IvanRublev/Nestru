defprotocol Nestru.PreDecoder do
  @fallback_to_any true

  @doc """
  Returns a map to be decoded into the struct adopting the Decoder protocol.

  `Nestru` calls this function as the first step of the decoding procedure.
  Useful to adapt the keys of the map to match the field names
  of the target struct and to specify default values for the missing keys.

  The first argument is an empty struct value adopting the protocol.

  The second argument is the context value given to the `Nestru.decode/3` function call.

  The third argument is a map or a binary given to the `Nestru.decode/3` function call.

  If the function returns `{:ok, map_or_binary}`, then the `map_or_binary`
  will be decoded into the struct on the next step
  using the hint from `Nestru.Decoder.decode_fields_hint/3`.

  If the function returns `{:error, message}` tuple, then decoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  The default implementation returns the input value unmodified.

  To generate the keys translating implementation, set the `@derive` module
  attribute to the tuple of `Nestru.PreDecoder` and the `:translate` option
  specifying the map with key names translation.
  It's useful for copying the value from the input map with the given key
  to the decodable map with the struct filed key. See the example below.

  ## Examples

      def FruitEnergy do
        # Keys map can be given with deriving the protocol.
        # The following will make a function copying the value
        # of the "energy_factor" key into the :factor key in the map.
        @derive {Nestru.PreDecoder, translate: %{"energy_factor" => :factor}}

        @derive Nestru.Decoder

        defstruct [:value]
      end

      defmodule FruitBox do
        @derive Nestru.Decoder

        defstruct [:items]

        defimpl Nestru.PreDecoder do
          # Put values into the map with the struct's keys to be decoded later
          def gather_fields_for_decoding(_empty_struct, _context, value) do
            {:ok, %{items: Nestru.get(value, "elements"), name: "Default name"}}
          end
        end
      end
  """
  def gather_fields_for_decoding(empty_struct, context, value)
end

defimpl Nestru.PreDecoder, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    translation_map =
      if Keyword.has_key?(opts, :translate) do
        opts[:translate]
      else
        %{}
      end

    translation_map = Macro.escape(translation_map)

    quote do
      defimpl Nestru.PreDecoder, for: unquote(module) do
        def gather_fields_for_decoding(_empty_struct, _context, value) do
          {:ok,
           Enum.reduce(unquote(translation_map), value, fn {from, to}, map ->
             Map.put(map, to, Nestru.get(map, from))
           end)}
        end
      end
    end
  end

  def gather_fields_for_decoding(_empty_struct, _context, value), do: {:ok, value}
end
