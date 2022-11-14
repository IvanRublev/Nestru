defmodule NestruDeriveTest do
  use ExUnit.Case, async: true

  require Protocol
  import ExUnit.CaptureIO

  describe "Derive of Nestru.Decoder protocol should" do
    test "raise error giving no hint map as option" do
      expected_error = """
      Nestru.Decoder protocol should be derived with map, \
      see from_map_hint/3 docs for details.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        capture_io(:stderr, fn ->
          Protocol.derive(Nestru.Decoder, LineItem, :not_a_map)
        end)
      end
    end

    test "generate from_map_hint/3 implementation for appropriate struct giving hint map as option" do
      map = %{
        items: [%{amount: 100}, %{amount: 150}],
        totals: %{sum: 250, discount: 50, total: 200}
      }

      assert Nestru.decode_from_map!(map, LineItemHolder) == %LineItemHolder{
               items: [%LineItem{amount: 100}, %LineItem{amount: 150}],
               totals: %Totals{discount: 50, sum: 250, total: 200}
             }
    end

    test "raise an error giving a struct not deriving protocol explicitly" do
      expected_error = """
      Please, @derive Nestru.Decoder protocol before defstruct/1 call \
      in OrderNoDecoder or defimpl the protocol in the module explicitly \
      to support decoding from map.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode_from_map(%{}, OrderNoDecoder)
      end
    end
  end

  describe "Derive of Nestru.Encoder protocol should" do
    test "generate default implementation for appropriate struct" do
      struct = %LineItem{amount: 100}

      assert Nestru.encode_to_map!(struct) == %{amount: 100}
    end

    test "raise an error giving a struct not deriving protocol explicitly" do
      expected_error = """
      Please, @derive Nestru.Encoder protocol before defstruct/1 call \
      in LineItemNoEncoder or defimpl the protocol in the module explicitly \
      to support encoding into map.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.encode_to_map(%LineItemNoEncoder{price: 200})
      end
    end
  end
end
