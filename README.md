# Nestru

[![Build Status](https://travis-ci.com/IvanRublev/Nestru.svg?branch=master)](https://travis-ci.com/IvanRublev/Nestru)
[![Coverage Status](https://coveralls.io/repos/github/IvanRublev/Nestru/badge.svg)](https://coveralls.io/github/IvanRublev/Nestru)
[![hex.pm version](http://img.shields.io/hexpm/v/nestru.svg?style=flat)](https://hex.pm/packages/nestru)

> Full documentation is on [hexdocs.pm](https://hexdocs.pm/nestru/)

> JSON parsing example is in [contentful-elixir-parse-example-nestru-domo](https://github.com/IvanRublev/contentful-elixir-parse-example-nestru-domo) repo.

[//]: # (Documentation)

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

---

<p align="center">
  <a href="https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FIvanRublev%2FNestru%2Fblob%2Fmaster%2FREADME.md">
    <img src="https://livebook.dev/badge/v1/blue.svg" alt="Run in Livebook" />
  </a>
</p>

```elixir
Mix.install [:nestru], force: true, consolidate_protocols: false
```

---

Typical usage looks like the following:

```elixir
defmodule Order do
  @derive Nestru.Encoder
  defstruct [:id, :items, :total]

  # Giving a hint to Nestru how to process the items list of structs
  # and the total struct, other fields go to struct as is.
  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, _map) do
      {:ok, %{
        items: &Nestru.from_list_of_maps(&1, LineItem),
        total: Total
      }}
    end
  end
end

defmodule LineItem do
  @derive [Nestru.Decoder, Nestru.Encoder]
  defstruct [:amount]
end

defmodule Total do
  @derive [Nestru.Decoder, Nestru.Encoder]
  defstruct [:sum]
end

map = %{
  "id" => "A548",
  "items" => [%{"amount" => 150}, %{"amount" => 350}],
  "total" => %{"sum" => 500}
}

{:ok, model} = Nestru.from_map(map, Order)
```

```output
{:ok,
  %OrderA{
    id: "A548",
    items: [%LineItemA{amount: 150}, %LineItemA{amount: 350}],
    total: %Total{sum: 500}
  }}
```

And going back to the map is as simple as that:

```elixir
map = Nestru.to_map(model)
```

```output
%{
  id: "A548",
  items: [%{amount: 150}, %{amount: 350}],
  total: %{sum: 500}
}
```

## Maps with different key names

In some cases, the map's keys have slightly different names compared 
to the target's struct field names. Fields that should be decoded into the struct 
can be gathered by adopting `Nestru.PreDecoder` protocol like the following:

```elixir
defmodule Quote do
  @derive Nestru.Decoder

  defstruct [:cost]

  defimpl Nestru.PreDecoder do
    def gather_fields_map(_value, _context, map) do
      {:ok, %{cost: map["cost_value"]}}
    end
  end
end

map = %{
  "cost_value" => 1280
}

Nestru.from_map(map, Quote)
```

```output
{:ok, %Quote{cost: 1280}}
```

## Serializing type-dependent fields

To convert a struct with a field that can have the value of multiple struct types
into the map and back, the type of the field's value should be persisted. 
It's possible to do that like the following:

```elixir
defmodule BookCollection do
  defstruct [:name, :items]

  defimpl Nestru.Encoder do
    def to_map(struct) do
      items_kinds = Enum.map(struct.items, fn %module{} ->
        module
        |> Module.split()
        |> Enum.join(".")
      end)

      items = Enum.map(struct.items, fn item ->
        {:ok, map} = Nestru.to_map(item)
        map
      end)

      {:ok, %{name: struct.name, items_kinds: items_kinds, items: items}}
    end
  end

  defimpl Nestru.Decoder do
    def from_map_hint(_value, _context, map) do
      items_kinds = Enum.map(map.items_kinds, fn module_string ->
        module_string
        |> String.split(".")
        |> Module.safe_concat()
      end)

      {:ok, %{items: &Nestru.from_list_of_maps(&1, items_kinds)}}
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

{:ok, map} = Nestru.to_map(collection)
```

```output
{:ok, 
 %{
  name: "Duke of Norfolk's archive",
  items_kinds: ["BookCollection.Book", "BookCollection.Magazine"],
  items: [%{title: "The Spell in the Chasm"}, %{issue: "Strange Hunt"}]
 }}
```

And restoring of the original nested struct is as simple as that:

```elixir
{:ok, collection} = Nestru.from_map(map, BookCollection)
```

```output
{:ok, 
 %BookCollection{
  name: "Duke of Norfolk's archive",
  items: [
    %Book{title: "The Spell in the Chasm"},
    %Magazine{issue: "Strange Hunt"}
  ]
 }}
```

## Error handling and path to the failed part of the map

Every implemented function of Nestru protocols can return `{error, message}` tuple 
in case of failure.

When `Nestru` receives the error tuple, it stops conversion and bypasses the error to the caller.
However, before doing so, the library wraps the error message into a map and adds `path` 
and `get_in_keys` fields to it. The path values point to the failed part of the map 
like the following:

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

map = %{
  "street" => %{
    "house" => %{
      "name" => "Party house"
    }
  }
}

{:error, error} = Nestru.from_map(map, Location)
```

```output
{:error,
 %{
   get_in_keys: [#Function<8.5372299/3 in Access.key!/1>, #Function<8.5372299/3 in Access.key!/1>],
   message: "Can't continue without house number.",
   path: [:street, :house]
 }}
```

The failed part of the map can be returned like the following:

```elixir
get_in(map, error.get_in_keys)
```

```output
%{name: "Party house"}
```

## Use with other libraries

### Jason

JSON maps decoded with [Jason library](https://github.com/michalmuskala/jason/) 
are supported with both binary and atoms keys.

### ExJSONPath

[ExJsonPath library](https://hex.pm/packages/exjsonpath) allows querying maps
(JSON objects) and lists (JSON arrays), using JSONPath expressions.
The queries can be useful in `Nestru.PreDecoder.gather_fields_map/3`
function to assemble fields for decoding from a map having a very different shape
from the target struct.

### Domo

Consider using the [Domo library](https://github.com/IvanRublev/Domo) 
to validate the types of the nested struct values after decoding with `Nestru`.
`Domo` can validate a nested struct in one pass, ensuring that 
the struct's field values match its `t()` type and associated preconditions.

[//]: # (Documentation)

## Changelog

### 0.1.1
* Add `has_key?/2` and `get/3` map functions that look up keys 
  both in a binary or an atom form.

### 0.1.0
* Initial release.

## License

Copyright © 2021 Ivan Rublev

This project is licensed under the [MIT license](LICENSE).
