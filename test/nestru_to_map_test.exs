defmodule NestruToMapTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  describe "For a struct adopting Encoding protocol Nestru should" do
    test "encode struct to map receiving customized map value from Nestru.Encoder.to_map/1" do
      struct = %Order{id: "123785-558", max_total: 500.00}

      assert {:ok, %{max_total: 50_000}} = Nestru.to_map(struct)
      assert %{max_total: 50_000} = Nestru.to_map!(struct)
    end

    test "encode list of structs to map" do
      list = [
        %Order{id: "1", max_total: 500.00},
        %Order{id: "2", max_total: 600.00},
        %Order{id: "3", max_total: 700.00}
      ]

      assert {:ok, [%{max_total: 50_000}, %{max_total: 60_000}, %{max_total: 70_000}]} =
               Nestru.to_map(list)

      assert [%{max_total: 50_000}, %{max_total: 60_000}, %{max_total: 70_000}] =
               Nestru.to_map!(list)
    end

    test "encode nested struct to nested map" do
      struct = %Order{
        id: "1",
        totals: %Totals{sum: 345.00, discount: 20.00, total: 325.00},
        empty_totals: nil
      }

      assert {:ok, %{totals: %{sum: 345.00, discount: 20.00, total: 325.00}, empty_totals: nil}} =
               Nestru.to_map(struct)

      assert %{totals: %{sum: 345.00, discount: 20.00, total: 325.00}, empty_totals: nil} =
               Nestru.to_map!(struct)
    end

    test "returns input value given to Nestru.to_map(!)/1 if it's not a struct" do
      assert Nestru.to_map(nil) == {:ok, nil}
      assert Nestru.to_map!(nil) == nil
    end

    test "put nil value into the nested map receiving {:ok, nil} from Nestru.Encoder.to_map/1" do
      struct = %OrderNonNegativeTotal{max_total: 150}

      assert Nestru.to_map(struct) == {:ok, %{max_total: 150}}
      assert Nestru.to_map!(struct) == %{max_total: 150}

      struct = %OrderNonNegativeTotal{max_total: -1}

      assert Nestru.to_map(struct) == {:ok, nil}
      assert Nestru.to_map!(struct) == nil
    end

    test "raise an error receiving not {:ok, nil | map} | {:error, term} from Nestru.Encoder.to_map/1" do
      struct = %OrderWrongAdoption{id: 1}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.to_map/1 function \
      implemented for OrderWrongAdoption, received :nan instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.to_map!(struct)
      end

      struct = %OrderWrongAdoption{id: 2}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.to_map/1 function \
      implemented for OrderWrongAdoption, received :error instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.to_map!(struct)
      end

      struct = %OrderWrongAdoption{id: 3}

      expected_message = """
      Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.to_map/1 function \
      implemented for OrderWrongAdoption, received {:ok, :nan} instead.\
      """

      assert {:error, %{message: ^expected_message}} = Nestru.to_map(struct)

      assert_raise RuntimeError, regex_substring(expected_message), fn ->
        Nestru.to_map!(struct)
      end
    end

    test "bypass error returned from Nestru.Encoder.to_map/1" do
      assert {:error, %{message: "internal error"}} = Nestru.to_map(%OrderInternalError{id: "1"})

      assert_raise RuntimeError, regex_substring("internal error"), fn ->
        Nestru.to_map!(%OrderInternalError{id: "1"})
      end
    end
  end
end
