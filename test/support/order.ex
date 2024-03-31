defmodule Leaf do
  @moduledoc false

  @derive {Nestru.Decoder, hint: %{leaf: Leaf}}
  defstruct [:leaf, :value]
end

defmodule Invoice do
  @moduledoc false

  @derive [
    Nestru.Decoder,
    {Nestru.PreDecoder, translate: %{"totalSum" => :total_sum, atom_key: :key}}
  ]
  defstruct [:total_sum, :key]
end

defmodule OrdersBook do
  @moduledoc false

  @derive Nestru.Encoder

  defstruct [:orders]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      case value[:orders] do
        # wrong
        [_] -> {:ok, %{orders: Order}}
        # correct
        [_, _] -> {:ok, %{orders: &Nestru.decode_from_list(&1, Order)}}
        _ -> {:ok, %{orders: [Order]}}
      end
    end
  end
end

defmodule Order do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id, :max_total, :items, :totals, :empty_totals, :maybe_totals]

  defimpl Nestru.PreDecoder do
    def gather_fields_for_decoding(_empty_struct, context, value) do
      cond do
        Map.has_key?(value, :gather_max_total_custom_key) ->
          {:ok, Map.put(value, :max_total, value.gather_max_total_custom_key)}

        Map.has_key?(value, :gather_wrong_return) ->
          :not_a_tuple

        Map.has_key?(value, :gather_failed) ->
          {:error, "gather failed"}

        Map.has_key?(value, :context_to_max_total) ->
          {:ok, Map.put(value, :max_total, context)}

        true ->
          {:ok, value}
      end
    end
  end

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, context, _value) do
      if is_list(context) and context[:override_max_total] do
        {:ok, %{max_total: fn _ -> {:ok, context[:override_max_total]} end}}
      else
        {:ok,
         %{
           max_total: &{:ok, &1 && &1 / 100.0},
           totals: Totals,
           empty_totals: Totals
         }}
      end
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, :keep_one_field) do
      {:ok, %{max_total: if(struct.max_total, do: round(struct.max_total * 100))}}
    end

    def gather_fields_from_struct(struct, _context) do
      {:ok, Map.from_struct(struct)}
    end
  end
end

defmodule OrderOnlyName do
  @moduledoc false
  @derive {Nestru.Encoder, only: [:name]}

  defstruct [:a, :b, :name]
end

defmodule OrderExceptName do
  @moduledoc false
  @derive {Nestru.Encoder, except: [:name]}

  defstruct [:a, :b, :name]
end

defmodule LineItem do
  @moduledoc false

  @derive [Nestru.Encoder, Nestru.Decoder]
  defstruct [:amount]
end

defmodule LineItemHolder do
  @moduledoc false

  @derive {
    Nestru.Decoder,
    hint: %{
      items: &__MODULE__.decode_items/1,
      totals: Totals
    }
  }

  def decode_items(value), do: Nestru.decode_from_list(value, LineItem)

  defstruct [:items, :totals]
end

defmodule Totals do
  @moduledoc false

  @enforce_keys [:total]
  defstruct [:sum, :discount, :total]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      if Map.get(value, :total, 0) > 500 do
        {:error, "total can't be greater then 500"}
      else
        {:ok, %{}}
      end
    end
  end

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, _context) do
      map = Map.from_struct(struct)

      if map.total > 500 do
        {:error, "total can't be greater then 500"}
      else
        {:ok, map}
      end
    end
  end
end
