defmodule Leaf do
  @moduledoc false

  @derive {Nestru.Decoder, %{leaf: Leaf}}
  defstruct [:leaf, :value]
end

defmodule Invoice do
  @moduledoc false

  @derive [
    Nestru.Decoder,
    {Nestru.PreDecoder, %{"totalSum" => :total_sum, atom_key: :key}}
  ]
  defstruct [:total_sum, :key]
end

defmodule OrdersBook do
  @moduledoc false

  @derive Nestru.Encoder

  defstruct [:orders]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      case map[:orders] do
        # wrong
        [_] -> {:ok, %{orders: Order}}
        # correct
        [_, _] -> {:ok, %{orders: &Nestru.decode_from_list_of_maps(&1, Order)}}
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
    def gather_fields_from_map(_value, context, map) do
      cond do
        Map.has_key?(map, :gather_max_total_custom_key) ->
          {:ok, Map.put(map, :max_total, map.gather_max_total_custom_key)}

        Map.has_key?(map, :gather_wrong_return) ->
          :not_a_tuple

        Map.has_key?(map, :gather_failed) ->
          {:error, "gather failed"}

        Map.has_key?(map, :context_to_max_total) ->
          {:ok, Map.put(map, :max_total, context)}

        true ->
          {:ok, map}
      end
    end
  end

  defimpl Nestru.Decoder do
    def from_map_hint(_value, context, _map) do
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

defmodule LineItem do
  @moduledoc false

  @derive [Nestru.Encoder, Nestru.Decoder]
  defstruct [:amount]
end

defmodule LineItemHolder do
  @moduledoc false

  @derive {
    Nestru.Decoder,
    %{
      items: &__MODULE__.decode_items/1,
      totals: Totals
    }
  }

  def decode_items(value), do: Nestru.decode_from_list_of_maps(value, LineItem)

  defstruct [:items, :totals]
end

defmodule Totals do
  @moduledoc false

  @enforce_keys [:total]
  defstruct [:sum, :discount, :total]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      if Map.get(map, :total, 0) > 500 do
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
