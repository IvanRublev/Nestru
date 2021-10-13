defmodule NestruPreDecoderTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  describe "For a struct adopting PreDecoder protocol Nestru should" do
    test "gather fields input map before processing into struct" do
      map = %{
        id: "123785-558",
        gather_max_total_custom_key: 50_000
      }

      assert {:ok, %Order{max_total: 500.00}} = Nestru.from_map(map, Order)
      assert %Order{max_total: 500.00} = Nestru.from_map!(map, Order)
    end

    test "bypass error received" do
      map = %{gather_failed: 50_000}

      expected_error = "gather failed"

      assert {:error, %{message: ^expected_error}} = Nestru.from_map(map, Order)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.from_map!(map, Order)
      end
    end

    test "return error receiving not a {:ok | :error, term} from gather function" do
      map = %{gather_wrong_return: 50_000}

      expected_error = """
      Expected a {:ok, map} | {:error, term} value from Nestru.PreDecoder.gather_fields_map/3 \
      function implemented for Order, received :not_a_tuple instead.\
      """

      assert {:error, %{message: ^expected_error}} = Nestru.from_map(map, Order)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.from_map!(map, Order)
      end
    end
  end
end
