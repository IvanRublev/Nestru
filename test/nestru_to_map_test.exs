defmodule NestruToMapTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  describe "For a struct adopting Encoding protocol Nestru should" do
    test "encode struct to map receiving customized map value from Nestru.Encoder.gather_fields_from_struct/2" do
      struct = %Order{id: "123785-558", max_total: 500.00}

      assert {:ok, %{max_total: 50_000}} == Nestru.encode_to_map(struct, :keep_one_field)
      assert %{max_total: 50_000} == Nestru.encode_to_map!(struct, :keep_one_field)
    end

    test "encode struct to map given :only and :except parameters deriving Encoder" do
      struct = %OrderOnlyName{a: "123785-558", b: "bbb", name: "only"}

      assert {:ok, %{name: "only"}} == Nestru.encode_to_map(struct)
      assert %{name: "only"} == Nestru.encode_to_map!(struct)

      struct = %OrderExceptName{a: "123785-558", b: "bbb", name: "except"}

      assert {:ok, %{a: "123785-558", b: "bbb"}} == Nestru.encode_to_map(struct)
      assert %{a: "123785-558", b: "bbb"} == Nestru.encode_to_map!(struct)
    end

    test "return error giving not a struct value to encode_to_map(!)/1" do
      assert_raise RuntimeError, regex_substring("expects a struct as input value"), fn ->
        Nestru.encode_to_map(nil)
      end

      assert_raise RuntimeError, regex_substring("expects a struct as input value"), fn ->
        Nestru.encode_to_map!(nil)
      end
    end

    test "encode nested struct to nested map" do
      struct = %Order{
        id: "1",
        totals: %Totals{sum: 345.00, discount: 20.00, total: 325.00},
        empty_totals: nil
      }

      assert {:ok, %{totals: %{sum: 345.00, discount: 20.00, total: 325.00}, empty_totals: nil}} =
               Nestru.encode_to_map(struct)

      assert %{totals: %{sum: 345.00, discount: 20.00, total: 325.00}, empty_totals: nil} =
               Nestru.encode_to_map!(struct)
    end

    test "put nil value into the nested map receiving {:ok, nil} from Nestru.Encoder.gather_fields_from_struct/2" do
      struct = %OrderNonNegativeTotal{max_total: 150}

      assert Nestru.encode_to_map(struct) == {:ok, %{max_total: 150}}
      assert Nestru.encode_to_map!(struct) == %{max_total: 150}

      struct = %OrderNonNegativeTotal{max_total: -1}

      assert Nestru.encode_to_map(struct) == {:ok, nil}
      assert Nestru.encode_to_map!(struct) == nil
    end

    test "raise an error receiving not {:ok, nil | map} | {:error, term} from Nestru.Encoder.gather_fields_from_struct/2" do
      struct = %OrderWrongAdoption{id: 1}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.gather_fields_from_struct/2 function \
      implemented for OrderWrongAdoption, received :nan instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.encode_to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.encode_to_map!(struct)
      end

      struct = %OrderWrongAdoption{id: 2}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.gather_fields_from_struct/2 function \
      implemented for OrderWrongAdoption, received :error instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.encode_to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.encode_to_map!(struct)
      end

      struct = %OrderWrongAdoption{id: 3}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.gather_fields_from_struct/2 function \
      implemented for OrderWrongAdoption, received {:ok, :nan} instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.encode_to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.encode_to_map!(struct)
      end
    end

    test "bypass error returned from Nestru.Encoder.gather_fields_from_struct/2" do
      assert {:error, %{message: "internal error"}} =
               Nestru.encode_to_map(%OrderInternalError{id: "1"})

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.encode_to_map!(%OrderInternalError{id: "1"})
      end
    end

    test "encode list of structs to map" do
      list = [
        %Order{id: "1", max_total: 500.00},
        %Order{id: "2", max_total: 600.00},
        %Order{id: "3", max_total: 700.00}
      ]

      assert {:ok, [%{max_total: 50_000}, %{max_total: 60_000}, %{max_total: 70_000}]} =
               Nestru.encode_to_list_of_maps(list, :keep_one_field)

      assert [%{max_total: 50_000}, %{max_total: 60_000}, %{max_total: 70_000}] =
               Nestru.encode_to_list_of_maps!(list, :keep_one_field)
    end

    test "bypass error failing to encode at least one struct to map from the list" do
      assert {:error, %{message: "internal error"}} =
               Nestru.encode_to_list_of_maps([
                 %Order{id: "1", max_total: 500.00},
                 %OrderInternalError{id: "1"}
               ])

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.encode_to_list_of_maps!([
          %Order{id: "1", max_total: 500.00},
          %OrderInternalError{id: "1"}
        ])
      end
    end
  end
end
