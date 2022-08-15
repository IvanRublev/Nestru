defprotocol Nestru.Decoder do
  @fallback_to_any true

  @doc """
  Returns the hint of how to decode the struct fields.

  The first argument is an empty struct value adopting the protocol.

  The second argument is the context value given to the `Nestru.decode_from_map/3` function call.

  The third argument is a map to be decoded into the struct.
  The map is useful to generate a hint for fields that have a dynamic struct type.

  If the function returns `{:ok, map}` then the `map`'s key-value pairs specify
  the decoding hint for a field with the key name and the value configuring the following:

    * A module's atom specifies that the appropriate field's value should
      be decoded as a nested struct defined in the module.
      Each field of the nested struct will be decoded recursively.

    * A one element list with module's atom specifies that the appropriate
      field's value should be decoded as a list of struct defined in the module.
      It's equivalent of returning `&Nestru.decode_from_list_of_maps(&1, module)`.

    * An anonymous function with arity 1 specifies that the appropriate
      field's value should be returned from the function.
      The function's only argument is the value from the map to be decoded and
      it expected to return `{:ok, term}`,
      `{:error, %{message: term, path: list}}`,
      or `{:error, term}`.

  Any field missing the key in the `map` receives the value as-is.
  The `%{}` empty `map` value defines that all fields of the
  struct take all values from the second argument's map unmodified.

  If the function returns `{:ok, nil}` then the decoded struct's value is nil.

  If the function returns `{:error, message}` tuple, then decoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  To generate the implementation of the function for the given struct,
  automatically set the `@derive module` attribute to the tuple of #{__MODULE__}
  and the `map` to be returned.

  ## Examples

      defmodule FruitBox do
        defstruct [:items]

        defimpl Nestru.Decoder do
          def from_map_hint(_value, _context, map) do
            # Give a function to decode the list field as a hint
            {:ok, %{items: &Nestru.decode_from_list_of_maps(&1, FruitBox.Fruit)}}
          end
        end
      end

      def FruitBox.Fruit do
        # Give a hint in a compact form with deriving the protocol
        @derive {Nestru.Decoder, %{vitamins: [Vitamin], energy: FruitEnergy}}

        defstruct [:vitamins, :energy]
      end

      def FruitEnergy do
        # Derive the default implementation
        @derive Nestru.Decoder

        defstruct [:value]
      end
  """
  def from_map_hint(value, context, map)
end

defimpl Nestru.Decoder, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    opts =
      cond do
        opts == [] ->
          %{}

        is_map(opts) ->
          opts

        true ->
          raise "Nestru.Decoder protocol should be derived with map, see from_map_hint/3 docs for details."
      end

    hint_map = Macro.escape(opts)

    quote do
      defimpl Nestru.Decoder, for: unquote(module) do
        def from_map_hint(_value, _context, _map) do
          {:ok, unquote(hint_map)}
        end
      end
    end
  end

  def from_map_hint(%module{} = _value, _context, _map) do
    raise "Please, @derive Nestru.Decoder protocol before defstruct/1 call in #{inspect(module)} or defimpl the protocol in the module explicitly to support decoding from map."
  end
end
