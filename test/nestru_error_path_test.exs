defmodule NestruErrorPathTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  test "Error message from Nestru.encode_to_map/1 should have path and get_in_keys pointing to a wrong part of nested struct" do
    wrong_item = %Totals{sum: 345.00, discount: 20.00, total: 600.00}

    struct = %OrdersBook{
      orders: [
        %Order{id: "1"},
        %Order{id: "2", totals: wrong_item}
      ]
    }

    expected_get_in_keys = [Access.key!(:orders), Access.at!(1), Access.key!(:totals)]
    assert get_in(struct, expected_get_in_keys) == wrong_item

    expected_path = [:orders, 1, :totals]

    assert {:error, %{get_in_keys: ^expected_get_in_keys, path: ^expected_path}} =
             Nestru.encode_to_map(struct)

    expected_regex =
      regex_substring("""
      See details by calling get_in/2 with the struct and the following \
      keys: [Access.key!(:orders), Access.at!(1), Access.key!(:totals)]\
      """)

    assert_raise RuntimeError, expected_regex, fn ->
      Nestru.encode_to_map!(struct)
    end
  end

  test "Nestru should join error path with one returned from Nestru.Encoder.gather_fields_from_struct/2" do
    wrong_item = %Totals{sum: 345.00, discount: 20.00, total: 600.00}

    list_of_structs = [
      %Order{id: "123"},
      %OrdersBook{
        orders: [
          %Order{id: "1"},
          %Order{id: "2", totals: wrong_item}
        ]
      }
    ]

    expected_get_in_keys = [
      Access.at!(1),
      Access.key!(:orders),
      Access.at!(1),
      Access.key!(:totals)
    ]

    assert get_in(list_of_structs, expected_get_in_keys) == wrong_item

    expected_path = [1, :orders, 1, :totals]

    assert {:error, %{get_in_keys: ^expected_get_in_keys, path: ^expected_path}} =
             Nestru.encode_to_list_of_maps(list_of_structs)

    expected_regex =
      regex_substring("""
      See details by calling get_in/2 with the list and the following \
      keys: [Access.at!(1), Access.key!(:orders), Access.at!(1), Access.key!(:totals)]\
      """)

    assert_raise RuntimeError, expected_regex, fn ->
      Nestru.encode_to_list_of_maps!(list_of_structs)
    end
  end

  test "Error message from Nestru.decode_from_map/3 should have path and get_in_keys pointing to a wrong part of map" do
    wrong_item = %{sum: 345.00, discount: 20.00, total: 600.00}

    map = %{
      orders: [
        %{id: "1"},
        %{:id => "2", "totals" => wrong_item}
      ]
    }

    expected_get_in_keys = [Access.key!(:orders), Access.at!(1), Access.key!("totals")]
    assert get_in(map, expected_get_in_keys) == wrong_item

    expected_path = [:orders, 1, "totals"]

    assert {:error, %{get_in_keys: ^expected_get_in_keys, path: ^expected_path}} =
             Nestru.decode_from_map(map, OrdersBook)

    expected_regex =
      regex_substring("""
      See details by calling get_in/2 with the map and the following \
      keys: [Access.key!(:orders), Access.at!(1), Access.key!("totals")]\
      """)

    assert_raise RuntimeError, expected_regex, fn ->
      Nestru.decode_from_map!(map, OrdersBook)
    end
  end

  test "Nestru should generate failed path up to key with failed function from Nestru.Decoder.from_map_hint/3" do
    map = %{only_message_in_error: true}

    assert {:error, %{path: [:id]}} = Nestru.decode_from_map(map, OrderWrongItemFunction)

    assert_raise RuntimeError, regex_substring("[Access.key!(:id)]"), fn ->
      Nestru.decode_from_map!(map, OrderWrongItemFunction)
    end
  end

  test "Nestru should join error path with one returned from Nestru.Decoder.from_map_hint/3" do
    map = %{items: [%{id: "2"}]}

    assert {:error, %{path: [:items, 0, :id, :some, :subpath]}} =
             Nestru.decode_from_map(map, ErroredItemsBook)

    assert_raise RuntimeError,
                 regex_substring("Access.key!(:id), Access.key!(:some), Access.key!(:subpath)]"),
                 fn ->
                   Nestru.decode_from_map!(map, ErroredItemsBook)
                 end
  end

  test "Nestru should raise error getting path with not atom or string from Nestru.Decoder.from_map_hint/3" do
    map = %{items: [%{id: "3"}]}

    expected_error =
      Regex.compile!(
        Regex.escape("""
        Error path can contain only not nil atoms, binaries or integers. \
        Error is {:error, %{message: \"failure message\", path: [:some, nil]}}, \
        received from function #Function<\
        """) <>
          ".*" <> Regex.escape("/1 in Nestru.Decoder.OrderItemFunctionError.from_map_hint/3>.")
      )

    assert_raise RuntimeError, expected_error, fn ->
      Nestru.decode_from_map(map, ErroredItemsBook)
    end

    assert_raise RuntimeError, expected_error, fn ->
      Nestru.decode_from_map!(map, ErroredItemsBook)
    end
  end
end
