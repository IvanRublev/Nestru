defprotocol Nestru.Decoder do
  @fallback_to_any true

  @doc """
  Returns the hint of how to decode the struct fields.

  The first argument is an empty struct value adopting the protocol.

  The second argument is the context value given to the `Nestru.decode/3` function call.

  The third argument is a map or a binary to be decoded into the struct.

  If the function returns `{:ok, hint}`, then the `hint` is expected to be a map or
  an instance of the decodable struct.

  When the map is returned then, key-value pairs give the decoding hint about
  the struct's fields with the key equal to field's name and the value specifying
  the following:

    * A module's atom (f.e. `Module`) specifies that the appropriate field's
      value should be decoded as a nested struct defined in the module.
      Each field of the nested struct will be decoded recursively.

    * A one-element list with the module's atom (f.e. `[Module]`) specifies
      that the appropriate field's value should be decoded as a list of structs.
      It's equivalent of returning `&Nestru.decode_from_list(&1, module)`.

    * An anonymous function with arity 1 (f.e. `&my_fun/1`) specifies
      that the appropriate field's value should be returned from the function.
      The function's only argument is the value from the map to be decoded, and
      it is expected to return `{:ok, term}`,
      `{:error, %{message: term, path: list}}`, or `{:error, term}`.

  Any field missing the key in the `hint` receives the value as-is from the input map.
  The `%{}` empty `hint` value defines that all fields of the struct
  take all values from the input map unmodified.

  When the returned `hint` is an instance of the decodable struct, then it is
  returned as is.

  If the function returns `{:ok, nil}`, then the decoded struct's value is nil.

  If the function returns `{:error, message}` tuple, then decoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  To generate the implementation of the function for the given struct in short form,
  set the `@derive module` attribute to the tuple of `#{inspect(__MODULE__)}`
  and the `:hint` option specifying the hint map to be returned.

  The default implementation derived for the struct pulls all values from
  the input map unmodified.

  See the examples below.

  ## Examples

      def Supplier do
        # Derive the default implementation
        @derive Nestru.Decoder

        defstruct [:id, :name]
      end

      def FruitBox.Fruit do
        # Give a hint in a compact form with deriving the protocol
        @derive {Nestru.Decoder, hint: %{vitamins: [Vitamin], supplier: Supplier}}

        defstruct [:vitamins, :supplier]
      end

      defmodule FruitBox do
        defstruct [:items]

        # Implement the function returning the hint explicitly
        defimpl Nestru.Decoder do
          def decode_fields_hint(_empty_struct, _context, value) do
            # Give a function to decode the list field as a hint, other fields are copied as is
            {:ok, %{items: &Nestru.decode_from_list(&1, FruitBox.Fruit)}}
          end
        end
      end
  """
  def decode_fields_hint(empty_struct, context, value)
end

defimpl Nestru.Decoder, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    hint_map =
      if Keyword.has_key?(opts, :hint) do
        opts[:hint]
      else
        %{}
      end

    hint_map = Macro.escape(hint_map)

    quote do
      defimpl Nestru.Decoder, for: unquote(module) do
        def decode_fields_hint(_empty_struct, _context, _value) do
          {:ok, unquote(hint_map)}
        end
      end
    end
  end

  def decode_fields_hint(%module{} = _empty_struct, _context, _value) do
    exception_text =
      if module in [DateTime, URI, Range] do
        "Please, defimpl the protocol for the #{inspect(module)} module explicitly to support decoding from a map or a binary. \
See an example on how to decode modules from Elixir on https://github.com/IvanRublev/Nestru#date-time-and-uri"
      else
        "Please, @derive Nestru.Decoder protocol before defstruct/1 call in #{inspect(module)} or defimpl the protocol in the module explicitly to support decoding from a map or a binary."
      end

    raise exception_text
  end
end
