defmodule NestruPreDecoderTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  describe "For a struct adopting PreDecoder protocol Nestru should" do
    test "gather fields input map before processing into struct" do
      map = %{
        id: "123785-558",
        gather_max_total_custom_key: 50_000
      }

      assert {:ok, %Order{max_total: 500.00}} = Nestru.decode(map, Order)
      assert %Order{max_total: 500.00} = Nestru.decode!(map, Order)
    end

    test "bypasses binary value as fields gathering result" do
      assert {:ok, %OrderBinary{max_total: 500.00}} =
               Nestru.decode("max_total: 500.00", OrderBinary)
    end

    test "configure fields gathering via deriving :translate directive" do
      map = %{
        "totalSum" => 125.0,
        "atom_key" => 5.0
      }

      assert {:ok, %Invoice{total_sum: 125.00, key: 5.0}} = Nestru.decode(map, Invoice)
      assert %Invoice{total_sum: 125.00, key: 5.0} = Nestru.decode!(map, Invoice)
    end

    test "bypass error received" do
      map = %{gather_failed: 50_000}

      expected_error = "gather failed"

      assert {:error, %{message: ^expected_error}} = Nestru.decode(map, Order)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.decode!(map, Order)
      end
    end

    test "return error receiving not a {:ok | :error, map | binary} from gather function" do
      map = %{gather_wrong_return: 50_000}

      expected_error = """
      Expected a {:ok, map | binary} | {:error, term} value from Nestru.PreDecoder.gather_fields_for_decoding/3 \
      function implemented for Order, received :not_a_tuple instead.\
      """

      assert {:error, %{message: ^expected_error}} = Nestru.decode(map, Order)

      assert_raise RuntimeError, regex_substring(expected_error), fn ->
        Nestru.decode!(map, Order)
      end
    end
  end
end
