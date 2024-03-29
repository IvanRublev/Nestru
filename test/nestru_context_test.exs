defmodule NestruContextTest do
  use ExUnit.Case, async: true

  describe "Given a context value Nestru should" do
    test "pass the context value to PreDecoder.gather_fields_from_map/1" do
      map = %{
        id: "123785-558",
        context_to_max_total: true
      }

      context = 15_000

      assert {:ok, %Order{max_total: 150.00}} = Nestru.decode_from_map(map, Order, context)
      assert %Order{max_total: 150.00} = Nestru.decode_from_map!(map, Order, context)
    end

    test "pass the context value to Decoder.from_map_hint/1" do
      map = %{
        id: "123785-558",
        max_total: 15_000
      }

      context = [override_max_total: 250]

      assert {:ok, %Order{max_total: 250}} = Nestru.decode_from_map(map, Order, context)
      assert %Order{max_total: 250} = Nestru.decode_from_map!(map, Order, context)
    end

    test "pass the context decoding a list of maps" do
      list = [
        %{id: "1", context_to_max_total: true},
        %{id: "2", context_to_max_total: true},
        %{id: "3", context_to_max_total: true}
      ]

      context = 15_000

      assert {:ok,
              [
                %Order{max_total: 150.00},
                %Order{max_total: 150.00},
                %Order{max_total: 150.00}
              ]} = Nestru.decode_from_list_of_maps(list, Order, context)

      assert [
               %Order{max_total: 150.00},
               %Order{max_total: 150.00},
               %Order{max_total: 150.00}
             ] = Nestru.decode_from_list_of_maps!(list, [Order, Order, Order], context)
    end
  end
end
