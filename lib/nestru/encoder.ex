defprotocol Nestru.Encoder do
  @fallback_to_any true

  @doc """
  Returns the fields gathered from the given struct, which can be encoded further.

  It can be used to rename the keys of the map, or to turn the whole struct to binary.

  The first argument is the encodable struct value adopting the protocol.

  The second argument is the context given to `encode/2`
  or `encode_to_list_of_maps/2` functions.

  `Nestru` calls this function as the first step of the encoding procedure.

  If the function returns `{:ok, item}`, then the encoding continues
  depending on the value of the `item` as follows:

  * for a binary, the encoding finishes, and the binary is returned
  * for a map, the encoding continues for each key-value pair. If the value is a struct
  then it is encoded into a map with `encode/1`, the same is done recursively for lists,
  all other values are left as they are.

  If the function returns `{:error, message}` tuple, then encoding stops, and
  the error is bypassed to the caller.

  Any other return value raises an error.

  To generate the default implementation of the function, add
  the `@derive #{inspect(__MODULE__)}` attribute to the struct.
  The `:only` and `:except` options are supported to filter the fields.

  The default implementation gathers keys from the struct
  by calling `Map.from_struct/1`.

  ## Examples

      def Supplier do
        # Derive the default implementation
        @derive Nestru.Encoder

        defstruct [:id, :name]
      end

      def Purchaser do
        # Encode only one field
        @derive {Nestru.Encoder, only: [:id]}

        defstruct [:id, :name, :address]
      end

      defmodule BoxLabel do
        defstruct [:prefix, :number]

        # Encode label as a binary
        defimpl Nestru.Encoder do
          def gather_fields_from_struct(struct, _context) do
            {:ok, "FF{struct.prefix}-{struct.number}"}
          end
        end
      end

      defmodule FruitBox do
        defstruct [:items, :label]

        # Rename the :items key to :elements in the result map
        defimpl Nestru.Encoder do
          def gather_fields_from_struct(struct, _context) do
            map = Map.from_struct(struct)

            {:ok,
             map
             |> Map.put(:elements, Map.get(map, :items))
             |> Map.delete(:items)}
          end
        end
      end
  """
  def gather_fields_from_struct(struct, context)
end

defimpl Nestru.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    opts = opts || []

    drop_keys =
      cond do
        Keyword.has_key?(opts, :only) ->
          struct
          |> Map.keys()
          |> List.delete(:__struct__)
          |> Kernel.--(opts[:only])

        Keyword.has_key?(opts, :except) ->
          opts[:except]

        true ->
          []
      end

    drop_keys = Macro.escape(drop_keys)

    quote do
      defimpl Nestru.Encoder, for: unquote(module) do
        def gather_fields_from_struct(struct, _context) do
          {:ok,
           struct
           |> Map.from_struct()
           |> Map.drop(unquote(drop_keys))}
        end
      end
    end
  end

  def gather_fields_from_struct(%module{}, _context) do
    exception_text =
      if module in [DateTime, URI, Range] do
        "Please, defimpl the protocol for the #{inspect(module)} module explicitly to support encoding into a map or a binary. \
See an example on how to encode modules from Elixir on https://github.com/IvanRublev/Nestru#date-time-and-uri"
      else
        "Please, @derive Nestru.Encoder protocol before defstruct/1 call in #{inspect(module)} or defimpl the protocol in the module explicitly to support encoding into a map or a binary."
      end

    raise exception_text
  end
end
