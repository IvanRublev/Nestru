defmodule NestruFromMapTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import ErrorRegex

  describe "For a struct adopting Decoder protocol Nestru should" do
    test "merge the input map into struct receiving %{} from Decoder.from_map_hint/1" do
      map = %{
        id: "123785-558",
        max_total: 50_000
      }

      assert {:ok, %Order{max_total: 500.00}} = Nestru.decode_from_map(map, Order)
      assert %Order{max_total: 500.00} = Nestru.decode_from_map!(map, Order)
    end

    test "support multilevel nested structs" do
      map = %{leaf: %{leaf: %{value: 110}}}

      assert {:ok, %Leaf{leaf: %Leaf{leaf: %Leaf{value: 110}}}} =
               Nestru.decode_from_map(map, Leaf)

      assert %Leaf{leaf: %Leaf{leaf: %Leaf{value: 110}}} = Nestru.decode_from_map!(map, Leaf)
    end

    test "support both atom and string keys to put values to same named struct's fields" do
      map = %{
        :id => "123785-558",
        "max_total" => 50_000
      }

      assert {:ok, %Order{max_total: 500.00}} = Nestru.decode_from_map(map, Order)
      assert %Order{max_total: 500.00} = Nestru.decode_from_map!(map, Order)

      map = %{"amount" => 100}

      assert {:ok, %LineItem{amount: 100}} = Nestru.decode_from_map(map, LineItem)
      assert %LineItem{amount: 100} = Nestru.decode_from_map!(map, LineItem)

      map = %{:amount => 50}

      assert {:ok, %LineItem{amount: 50}} = Nestru.decode_from_map(map, LineItem)
      assert %LineItem{amount: 50} = Nestru.decode_from_map!(map, LineItem)

      map = %{"id" => 000, "totals" => %{total: 345.00}}

      assert {:ok, %Order{totals: %Totals{total: 345.00}}} = Nestru.decode_from_map(map, Order)
      assert %Order{totals: %Totals{total: 345.00}} = Nestru.decode_from_map!(map, Order)
    end

    test "decode struct field's value as a nested struct receiving it's atom as a value for appropriate key in the map from Decoder.from_map_hint/3" do
      map = %{
        id: "123785-558",
        totals: %{sum: 345.00, discount: 20.00, total: 325.00},
        empty_totals: nil
      }

      assert {:ok,
              %Order{
                totals: %Totals{sum: 345.00, discount: 20.00, total: 325.00},
                empty_totals: nil
              }} = Nestru.decode_from_map(map, Order)

      assert %Order{
               totals: %Totals{sum: 345.00, discount: 20.00, total: 325.00},
               empty_totals: nil
             } = Nestru.decode_from_map!(map, Order)
    end

    test "put a value into struct field receiving {:ok, value} from the function for the field in the map from Nestru.Decoder.from_map_hint/3" do
      map = %{
        orders: [
          %{id: "1"},
          %{id: "2"}
        ]
      }

      assert {:ok, %OrdersBook{orders: [%Order{id: "1"}, %Order{id: "2"}]}} =
               Nestru.decode_from_map(map, OrdersBook)

      assert %OrdersBook{orders: [%Order{id: "1"}, %Order{id: "2"}]} =
               Nestru.decode_from_map!(map, OrdersBook)
    end

    test "decode struct field's value as list of Order structs receiving [Order] as a value for appropriate key in the map from Decoder.from_map_hint/3" do
      map = %{
        orders: [
          %{id: "1"},
          %{id: "2"},
          %{id: "3"}
        ]
      }

      assert {:ok, %OrdersBook{orders: [%Order{id: "1"}, %Order{id: "2"}, %Order{id: "3"}]}} =
               Nestru.decode_from_map(map, OrdersBook)

      assert %OrdersBook{orders: [%Order{id: "1"}, %Order{id: "2"}, %Order{id: "3"}]} =
               Nestru.decode_from_map!(map, OrdersBook)
    end

    test "bubble up error receiving {:error, message} from the function for the field in the map from Nestru.Decoder.from_map_hint/3" do
      map = %{id: "1"}

      expected_error = "something went wrong"

      assert {:error, %{message: ^expected_error}} =
               Nestru.decode_from_map(map, OrderItemFunctionError)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.decode_from_map!(map, OrderItemFunctionError)
      end
    end

    test "bubble up extracted error message receiving {:error, %{message: term, path: list}} from the function for the field in the map from Nestru.Decoder.from_map_hint/3" do
      map = %{id: "2"}

      expected_error = "another thing went wrong"

      assert {:error, %{message: ^expected_error}} =
               Nestru.decode_from_map(map, OrderItemFunctionError)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.decode_from_map!(map, OrderItemFunctionError)
      end
    end

    test "return or raise error receiving not {:ok, term}, {:error, %{message: term, path: list}} from function for a field in the map from Nestru.Decoder.from_map_hint/3" do
      map = %{}

      expected_error = ~r"""
      Expected {:ok, term}, {:error, %{message: term, path: list}}, or %{:error, term} \
      return value from the anonymous function for the key defined in the following \
      {:ok, %{:id => #Function<.*/1 in Nestru.Decoder.OrderWrongItemFunction.from_map_hint/3>}} \
      tuple returned from Nestru.Decoder.from_map_hint/3 function implemented for OrderWrongItemFunction, \
      received 16 instead.\
      """

      assert {:error, %{message: error}} = Nestru.decode_from_map(map, OrderWrongItemFunction)
      assert error =~ expected_error

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map!(map, OrderWrongItemFunction)
      end
    end

    test "return or raise error receiving not a struct module, [module], or function value for a field in the map from Nestru.Decoder.from_map_hint/3" do
      map = %{id: "2"}

      expected_error = """
      Expected a struct's module atom, [struct_module_atom], or a function value for :max_total key received from \
      Nestru.Decoder.from_map_hint/3 function implemented for OrderWrongMap, received :hello instead.\
      """

      assert {:error, %{message: ^expected_error}} = Nestru.decode_from_map(map, OrderWrongMap)

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map!(map, OrderWrongMap)
      end

      map = %{id: "3"}

      expected_error = """
      Expected a struct's module atom, [struct_module_atom], or a function value for :max_total key received from \
      Nestru.Decoder.from_map_hint/3 function implemented for OrderWrongMap, received "hello" instead.\
      """

      assert {:error, %{message: ^expected_error}} = Nestru.decode_from_map(map, OrderWrongMap)

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map!(map, OrderWrongMap)
      end
    end

    test "return or raise error for field with list value receiving a struct atom for it from Nestru.from_map_hint/3" do
      map = %{orders: [%{id: "1"}]}

      expected_error = """
      Unexpected Order value received for :orders key from Nestru.Decoder.from_map_hint/3 \
      function implemented for OrdersBook. You can return &Nestru.decode_from_list_of_maps(&1, Order) \
      as a hint for list decoding.\
      """

      assert {:error, %{message: ^expected_error}} = Nestru.decode_from_map(map, OrdersBook)

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map!(map, OrdersBook)
      end
    end

    test "return nil instead of struct receiving {:ok, nil} from Nestru.Decoder.from_map_hint/3" do
      map = %{max_total: 50_000}

      assert {:ok, %OrderNonNegativeTotal{max_total: 50_000}} =
               Nestru.decode_from_map(map, OrderNonNegativeTotal)

      assert %OrderNonNegativeTotal{max_total: 50_000} =
               Nestru.decode_from_map!(map, OrderNonNegativeTotal)

      map = %{max_total: -1}

      assert Nestru.decode_from_map(map, OrderNonNegativeTotal) == {:ok, nil}
      assert Nestru.decode_from_map!(map, OrderNonNegativeTotal) == nil
    end

    test "raise a Nestru.decode_from_map! error for key-value pair in map returned from Decoder.from_map_hint/3 that not exists in the decoding struct" do
      map = %{
        id: "1",
        max_total: 50_000
      }

      expected_error = """
      The decoding hint value for key :max_totalll received from Nestru.Decoder.from_map_hint/3 \
      implemented for OrderWrongMap is unexpected because the struct hasn't a field with such key name.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map!(map, OrderWrongMap)
      end
    end

    test "print warning in Nestru.decode_from_map for key-value pair in map returned from Decoder.from_map_hint/3 that not exists in the decoding struct" do
      map = %{
        id: "1",
        max_total: 50_000
      }

      assert capture_io(:stderr, fn -> Nestru.decode_from_map(map, OrderWrongMap) end) =~ """
             The decoding hint value for key :max_totalll received from Nestru.Decoder.from_map_hint/3 \
             implemented for OrderWrongMap is unexpected because the struct hasn't a field with such key name.\
             """
    end

    test "return error decoding not a map" do
      map = 1

      expected_message =
        "Expected a map value received 1 instead. Can't convert it to a Leaf struct."

      assert {:error, %{message: ^expected_message}} = Nestru.decode_from_map(map, Leaf)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.decode_from_map!(map, Leaf)
      end
    end

    test "return error having a non map value for a field with a struct hint" do
      map = %{leaf: :nan}

      expected_message =
        "Expected a map value received :nan instead. Can't convert it to a Leaf struct."

      assert {:error, %{message: ^expected_message, path: [:leaf]}} =
               Nestru.decode_from_map(map, Leaf)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.decode_from_map!(map, Leaf)
      end
    end

    test "return the struct or raise error missing enforced root field in a map" do
      map = %{
        max_total: 50_000
      }

      assert {:ok, %Order{max_total: 500.00}} = Nestru.decode_from_map(map, Order)
      assert_raise ArgumentError, ~r/[:id]/, fn -> Nestru.decode_from_map!(map, Order) end
    end

    test "return the struct or raise error missing enforced nested field in a map" do
      map = %{
        id: "123785-558",
        totals: %{sum: 345.00, discount: 20.00}
      }

      assert {:ok, %Order{id: "123785-558", totals: %Totals{sum: 345.00, discount: 20.00}}} =
               Nestru.decode_from_map(map, Order)

      assert_raise ArgumentError, ~r/[:total]/, fn -> Nestru.decode_from_map!(map, Order) end
    end

    test "raise an error receiving not {:ok, nil | map} | {:error, term} from Nestru.Decoder.from_map_hint/3" do
      map = %{id: 1}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Decoder.from_map_hint/3 \
      function implemented for OrderWrongAdoption, received :nan instead.\
      """

      assert {:error, %{message: ^expected_message}} =
               Nestru.decode_from_map(map, OrderWrongAdoption)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.decode_from_map!(map, OrderWrongAdoption)
      end

      map = %{id: 2}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Decoder.from_map_hint/3 \
      function implemented for OrderWrongAdoption, received :error instead.\
      """

      assert {:error, %{message: ^expected_message}} =
               Nestru.decode_from_map(map, OrderWrongAdoption)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.decode_from_map!(map, OrderWrongAdoption)
      end

      map = %{id: 3}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Decoder.from_map_hint/3 \
      function implemented for OrderWrongAdoption, received {:ok, :nan} instead.\
      """

      assert {:error, %{message: ^expected_message}} =
               Nestru.decode_from_map(map, OrderWrongAdoption)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.decode_from_map!(map, OrderWrongAdoption)
      end
    end

    test "bypass error returned from Nestru.Decoder.from_map_hint/3" do
      assert {:error, %{message: "internal error"}} =
               Nestru.decode_from_map(%{}, OrderInternalError)

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.decode_from_map!(%{}, OrderInternalError)
      end
    end
  end

  describe "For a list of maps Nestru should" do
    test "shape list of structs giving struct module atom as second argument" do
      map = %{id: "1", max_total: 50_000}
      maps_list = [map, map]

      assert {:ok, [%Order{id: "1", max_total: 500.00}, %Order{id: "1", max_total: 500.00}]} =
               Nestru.decode_from_list_of_maps(maps_list, Order)

      assert [%Order{id: "1", max_total: 500.00}, %Order{id: "1", max_total: 500.00}] =
               Nestru.decode_from_list_of_maps!(maps_list, Order)
    end

    test "shape list of structs giving list of struct module atoms as second argument" do
      maps_list = [
        %{id: "1", max_total: 50_000},
        %{id: "2", totals: %{sum: 345.00, discount: 20.00, total: 325.00}}
      ]

      assert {:ok,
              [
                %OrderNonNegativeTotal{max_total: 50_000},
                %Order{id: "2", totals: %{sum: 345.00, discount: 20.00, total: 325.00}}
              ]} = Nestru.decode_from_list_of_maps(maps_list, [OrderNonNegativeTotal, Order])

      assert [
               %OrderNonNegativeTotal{max_total: 50_000},
               %Order{id: "2", totals: %{sum: 345.00, discount: 20.00, total: 325.00}}
             ] = Nestru.decode_from_list_of_maps!(maps_list, [OrderNonNegativeTotal, Order])
    end

    test "return first error receiving decode_from_map" do
      maps_list = [
        %{id: "1", max_total: 50_000},
        %{id: "2", totals: %{sum: 345.00, discount: 20.00, total: 325.00}}
      ]

      assert {:error, %{message: "internal error"}} =
               Nestru.decode_from_list_of_maps(maps_list, OrderInternalError)

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.decode_from_list_of_maps!(maps_list, OrderInternalError)
      end

      assert {:error, %{message: "internal error"}} =
               Nestru.decode_from_list_of_maps(maps_list, [Order, OrderInternalError])

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.decode_from_list_of_maps!(maps_list, [Order, OrderInternalError])
      end
    end

    test "return error when first argument is not a list" do
      map = %{}

      expected_messge = "The first argument should be a list. Got %{} instead."

      assert {:error, %{message: ^expected_messge}} =
               Nestru.decode_from_list_of_maps(map, [Order])

      assert_raise RuntimeError, regex_substring(expected_messge), fn ->
        Nestru.decode_from_list_of_maps!(map, [Order])
      end
    end

    test "return error when list size not equal to module atoms list" do
      maps_list = [
        %{id: "1", max_total: 50_000},
        %{id: "2", totals: %{sum: 345.00, discount: 20.00, total: 325.00}}
      ]

      expected_messge = """
      The map's list length (2) is expected to be equal \
      to the struct module atoms list length (1).\
      """

      assert {:error, %{message: ^expected_messge}} =
               Nestru.decode_from_list_of_maps(maps_list, [Order])

      assert_raise RuntimeError, regex_substring(expected_messge), fn ->
        Nestru.decode_from_list_of_maps!(maps_list, [Order])
      end
    end
  end
end
