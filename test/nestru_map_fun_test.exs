defmodule NestruMapFunTest do
  use ExUnit.Case, async: true

  import ErrorRegex

  describe "has_key?/2" do
    test "returns true if atom key or binary key exists, or false otherwise, giving an atom key" do
      assert Nestru.has_key?(%{key: :atom}, :key)
      assert Nestru.has_key?(%{"key" => :string}, :key)
      refute Nestru.has_key?(%{}, :key)
    end

    test "returns true if atom key or binary key exists, or false otherwise, giving a binary key" do
      assert Nestru.has_key?(%{key: :atom}, "key")
      assert Nestru.has_key?(%{"key" => :string}, "key")
      refute Nestru.has_key?(%{}, "key")
    end

    test "returns false given a binary key that is mapping to nonexisting atom" do
      refute Nestru.has_key?(%{}, "non_existing_atom_name")
    end

    test "raises BadMap error giving not a map" do
      assert_raise BadMapError, regex_substring("expected a map, got: nil"), fn ->
        Nestru.has_key?(nil, :key)
      end

      assert_raise BadMapError, regex_substring("expected a map, got: nil"), fn ->
        Nestru.has_key?(nil, "key")
      end
    end
  end

  describe "get/3" do
    test "returns atom or binary key's value, or default value otherwise, giving an atom key" do
      assert Nestru.get(%{key: :atom}, :key)
      assert Nestru.get(%{"key" => :string}, :key)
      assert Nestru.get(%{}, :key) == nil
      assert Nestru.get(%{}, :key, :none) == :none
    end

    test "returns atom or binary key's value, or default value otherwise, giving an binary key" do
      assert Nestru.get(%{key: :atom}, "key")
      assert Nestru.get(%{"key" => :string}, "key")
      assert Nestru.get(%{}, "key") == nil
      assert Nestru.get(%{}, "key", :none) == :none
    end

    test "returns nil given a binary key that is mapping to nonexisting atom" do
      refute Nestru.get(%{}, "non_existing_atom_name")
    end

    test "raises BadMap error giving not a map" do
      assert_raise BadMapError, regex_substring("expected a map, got: nil"), fn ->
        Nestru.get(nil, :key)
      end

      assert_raise BadMapError, regex_substring("expected a map, got: nil"), fn ->
        Nestru.get(nil, "key")
      end
    end
  end
end
