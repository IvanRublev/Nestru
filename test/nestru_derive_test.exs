defmodule NestruDeriveTest do
  use ExUnit.Case, async: true

  require Protocol

  describe "Derive of Nestru.Decoder protocol should" do
    test "generate decode_fields_hint/3 implementation for appropriate struct giving hint value as option" do
      map = %{
        items: [%{amount: 100}, %{amount: 150}],
        totals: %{sum: 250, discount: 50, total: 200}
      }

      assert Nestru.decode!(map, LineItemHolder) == %LineItemHolder{
               items: [%LineItem{amount: 100}, %LineItem{amount: 150}],
               totals: %Totals{discount: 50, sum: 250, total: 200}
             }
    end

    test "raise an error giving a struct not deriving protocol explicitly" do
      expected_error = """
      Please, @derive Nestru.Decoder protocol before defstruct/1 call \
      in OrderNoDecoder or defimpl the protocol in the module explicitly \
      to support decoding from a map or a binary.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.decode(%{}, OrderNoDecoder)
      end
    end

    test "raise an error an Elixir struct" do
      for elixir_module <- [DateTime, URI, Range] do
        module_name = elixir_module |> Module.split() |> Enum.join(".")

        expected_error = """
        Please, defimpl the protocol for the #{module_name} module explicitly to support decoding from a map or a binary. \
        See an example on how to decode modules from Elixir on https://github.com/IvanRublev/Nestru#date-time-and-uri\
        """

        assert_raise RuntimeError, expected_error, fn ->
          Nestru.decode(%{}, elixir_module)
        end
      end
    end
  end

  describe "Derive of Nestru.Encoder protocol should" do
    test "generate default implementation for appropriate struct" do
      struct = %LineItem{amount: 100}

      assert Nestru.encode!(struct) == %{amount: 100}
    end

    test "raise an error giving a struct not deriving protocol explicitly" do
      expected_error = """
      Please, @derive Nestru.Encoder protocol before defstruct/1 call \
      in LineItemNoEncoder or defimpl the protocol in the module explicitly \
      to support encoding into a map or a binary.\
      """

      assert_raise RuntimeError, expected_error, fn ->
        Nestru.encode(%LineItemNoEncoder{price: 200})
      end
    end

    test "raise an error giving an Elixir struct not deriving protocol explicitly" do
      for elixir_module <- [DateTime, URI, Range] do
        module_name = elixir_module |> Module.split() |> Enum.join(".")

        expected_error = """
        Please, defimpl the protocol for the #{module_name} module explicitly to support encoding into a map or a binary. \
        See an example on how to encode modules from Elixir on https://github.com/IvanRublev/Nestru#date-time-and-uri\
        """

        assert_raise RuntimeError, expected_error, fn ->
          Nestru.encode(struct(elixir_module, %{}))
        end
      end
    end
  end
end
