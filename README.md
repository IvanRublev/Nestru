# Nestru

```elixir
Mix.install([:nestru], force: true, consolidate_protocols: false)
```

## About

| [![Build Status](https://travis-ci.com/IvanRublev/Nestru.svg?branch=master)](https://travis-ci.com/IvanRublev/Nestru) | [![Coverage Status](https://coveralls.io/repos/github/IvanRublev/Nestru/badge.svg)](https://coveralls.io/github/IvanRublev/Nestru) | [![hex.pm version](http://img.shields.io/hexpm/v/nestru.svg?style=flat)](https://hex.pm/packages/nestru) |
| --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |

🔗 Full documentation is on [hexdocs.pm](https://hexdocs.pm/nestru/)

🔗 JSON parsing example is in [elixir-decode-validate-json-with-nestru-domo](https://github.com/IvanRublev/elixir-decode-validate-json-with-nestru-domo) repo.

### Description

<!-- Documentation -->

A library to serialize between maps and nested structs.

Turns a map into a nested struct according to hints given to the library.
And vice versa turns any nested struct into a map.

It works with maps/structs of any shape and complexity. For example, when map
keys are named differently than struct's fields. Or when fields can hold
values of various struct types conditionally.

The library's primary purpose is to serialize a JSON map; at the same time,
the map can be of any origin.

The map can have atom or binary keys. The library takes the binary key first 
and then the same-named atom key if the binary key is missing during 
the decoding of the map.

## Tour

<p align="center" class="hidden">
  <a href="https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FIvanRublev%2FNestru%2Fblob%2Fmaster%2FREADME.md">
    <img src="https://livebook.dev/badge/v1/blue.svg" alt="Run in Livebook" />
  </a>
</p>

Let's say we have an `Order` with `Total` that we want to decode from a map.
First, let's derive `Nestru.Decoder` protocol and specify that field `:total`
should hold a value of `Total` struct like the following:

```elixir
defmodule Order do
  @derive {Nestru.Decoder, %{total: Total}}
  defstruct [:id, :total]
end

defmodule Total do
  @derive Nestru.Decoder
  defstruct [:sum]
end
```

Now we decode the `Order` from the nested map like that:

```elixir
map = %{
  "id" => "A548",
  "total" => %{"sum" => 500}
}

{:ok, model} = Nestru.decode_from_map(map, Order)
```
```output
{:ok, %Order{id: "A548", total: %Total{sum: 500}}}
```

We get the order as the expected nested struct. Good!

Now we add the `:items` field to `Order` struct to hold a list of `LineItem`s:

```elixir
defmodule Order do
  @derive {Nestru.Decoder, %{total: Total}}
  defstruct [:id, :items, :total]
end

defmodule LineItem do
  @derive Nestru.Decoder
  defstruct [:amount]
end
```

and we decode the `Order` from the nested map like that:

```elixir
map = %{
  "id" => "A548",
  "items" => [%{"amount" => 150}, %{"amount" => 350}],
  "total" => %{"sum" => 500}
}

{:ok, model} = Nestru.decode_from_map(map, Order)
```
```output
{:ok, %Order{id: "A548", items: [%{"amount" => 150}, %{"amount" => 350}], total: %Total{sum: 500}}}
```

The `:items` field value of the `%Order{}` is still the list of maps 
and not structs 🤔 This is because `Nestru` has no clue what kind of struct 
these list items should be. So let's give a hint to `Nestru` on how to decode
that field:

```elixir
defmodule Order do
  @derive {Nestru.Decoder, %{total: Total, items: [LineItem]}}

  defstruct [:id, :items, :total]
end
```

Let's decode again:

```elixir
{:ok, model} = Nestru.decode_from_map(map, Order)
```
```output
{:ok,
 %Order{
   id: "A548",
   items: [%LineItem{amount: 150}, %LineItem{amount: 350}],
   total: %Total{sum: 500}
 }}
```

Voilà, we have field values as nested structs 🎉

For the case when the list contains several structs of different types, please,
see the Serializing type-dependent fields section below.

## Error handling and path to the failed part of the map

Every implemented function of Nestru protocols can return `{error, message}` tuple 
in case of failure. When `Nestru` receives the error tuple, it stops conversion
and bypasses the error to the caller.

```elixir
defmodule Location do
  @derive {Nestru.Decoder, %{street: Street}}
  defstruct [:street]
end

defmodule Street do
  @derive {Nestru.Decoder, %{house: House}}
  defstruct [:house]
end

defmodule House do
  defstruct [:number]

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      if Nestru.has_key?(map, :number) do
        {:ok, Nestru.get(map, :number)}
      else
        {:error, "Can't continue without house number."}
      end
    end
  end
end
```

So when we decode the following map missing the `number` value, we will get
the error back:

```elixir
map = %{
  "street" => %{
    "house" => %{
      "name" => "Party house"
    }
  }
}

{:error, error} = Nestru.decode_from_map(map, Location)
```
```output
{:error,
 %{
   get_in_keys: [#Function<8.67001686/3 in Access.key!/1>, #Function<8.67001686/3 in Access.key!/1>],
   message: "Can't continue without house number.",
   path: ["street", "house"]
 }}
```

`Nestru` wraps the error message into a map and adds `path` and `get_in_keys`
fields to it. The path values point to the failed part of the map which can
be returned like the following:

```elixir
get_in(map, error.get_in_keys)
```
```output
%{"name" => "Party house"}
```

## Maps with different key names

In some cases, the map's keys have slightly different names compared 
to the target's struct field names. Fields that should be decoded into the struct 
can be gathered by adopting `Nestru.PreDecoder` protocol like the following:

```elixir
defmodule Quote do
  @derive [
    {Nestru.PreDecoder, %{"cost_value" => :cost}},
    Nestru.Decoder
  ]

  defstruct [:cost]
end
```

When we decode the map, `Nestru` will put the value of the `"cost_value"` key
for the `:cost` key into the map and then complete the decoding:

```elixir
map = %{
  "cost_value" => 1280
}

Nestru.decode_from_map(map, Quote)
```
```output
{:ok, %Quote{cost: 1280}}
```

For more sophisticated key mapping you can implement 
the `gather_fields_map/3` function of `Nestru.PreDecoder` explicitly.

## Serializing type-dependent fields

To convert a struct with a field that can have the value of multiple struct types
into the map and back, the type of the field's value should be persisted. 
It's possible to do that like the following:

```elixir
defmodule BookCollection do
  defstruct [:name, :items]

  defimpl Nestru.Encoder do
    def encode_to_map(struct) do
      items_kinds =
        Enum.map(struct.items, fn %module{} ->
          module
          |> Module.split()
          |> Enum.join(".")
        end)

      items =
        Enum.map(struct.items, fn item ->
          {:ok, map} = Nestru.encode_to_map(item)
          map
        end)

      {:ok, %{name: struct.name, items_kinds: items_kinds, items: items}}
    end
  end

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      items_kinds =
        Enum.map(map.items_kinds, fn module_string ->
          module_string
          |> String.split(".")
          |> Module.safe_concat()
        end)

      {:ok, %{items: &Nestru.decode_from_list_of_maps(&1, items_kinds)}}
    end
  end
end

defmodule BookCollection.Book do
  @derive [Nestru.Encoder, Nestru.Decoder]
  defstruct [:title]
end

defmodule BookCollection.Magazine do
  @derive [Nestru.Encoder, Nestru.Decoder]
  defstruct [:issue]
end

alias BookCollection.{Book, Magazine}
```

Let's convert the nested struct into a map. The returned map gets 
extra `items_kinds` field with types information:

```elixir
collection = %BookCollection{
  name: "Duke of Norfolk's archive",
  items: [
    %Book{title: "The Spell in the Chasm"},
    %Magazine{issue: "Strange Hunt"}
  ]
}

{:ok, map} = Nestru.encode_to_map(collection)
```
```output
{:ok,
 %{
   items: [%{title: "The Spell in the Chasm"}, %{issue: "Strange Hunt"}],
   items_kinds: ["BookCollection.Book", "BookCollection.Magazine"],
   name: "Duke of Norfolk's archive"
 }}
```

And restoring of the original nested struct is as simple as that:

```elixir
{:ok, collection} = Nestru.decode_from_map(map, BookCollection)
```
```output
{:ok,
 %BookCollection{
   items: [
     %BookCollection.Book{title: "The Spell in the Chasm"},
     %BookCollection.Magazine{issue: "Strange Hunt"}
   ],
   name: "Duke of Norfolk's archive"
 }}
```

## Use with other libraries

### Jason

JSON maps decoded with [Jason library](https://github.com/michalmuskala/jason/) 
are supported with both binary and atoms keys.

### ex_json_schema

[ex_json_schema library](https://hex.pm/packages/ex_json_schema) can be used 
before decoding the input map with the JSON schema. To make sure that 
the structure of the input map is correct.

### ExJSONPath

[ExJsonPath library](https://hex.pm/packages/exjsonpath) allows querying maps
(JSON objects) and lists (JSON arrays), using JSONPath expressions.
The queries can be useful in `Nestru.PreDecoder.gather_fields_map/3`
function to assemble fields for decoding from a map having a very different shape
from the target struct.

### Domo

You can use the [Domo library](https://github.com/IvanRublev/Domo) 
to validate the `t()` types of the nested struct values after 
decoding with `Nestru`.

`Domo` can validate a nested struct in one pass, ensuring that 
the struct's field values match its `t()` type and associated preconditions.

<!-- Documentation -->

## Changelog

### 0.2.1

* Fix `decode_from_map(!)/2/3` to return the error for not a map value.

### 0.2.0

* Fix to ensure the module is loaded before checking if it's a struct
* Add `decode` and `encode` verbs to function names
* Support `[Module]` hint in the map returned from `from_map_hint` to decode the list of structs
* Support `%{one_key: :other_key}` mapping configuration for the `PreDecoder` protocol in `@derive` attribute.

### 0.1.1

* Add `has_key?/2` and `get/3` map functions that look up keys 
  both in a binary or an atom form.

### 0.1.0

* Initial release.

## License

Copyright © 2021 Ivan Rublev

This project is licensed under the [MIT license](LICENSE).
