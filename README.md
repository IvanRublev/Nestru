# Nestru

[![Build Status](https://travis-ci.com/IvanRublev/Nestru.svg?branch=master)](https://travis-ci.com/IvanRublev/Nestru)
[![Coverage Status](https://coveralls.io/repos/github/IvanRublev/Nestru/badge.svg)](https://coveralls.io/github/IvanRublev/Nestru)
[![hex.pm version](http://img.shields.io/hexpm/v/nestru.svg?style=flat)](https://hex.pm/packages/nestru)

> Full documentation is on [hexdocs.pm](https://hexdocs.pm/nestru/)

[//]: # (Documentation)

A library to serialize between maps and nested structs.

Turns map of any shape into a model of nested structs according to hints given
to the library. Turns any nested struct into a map.

The library's primary purpose is to serialize between JSON map 
and an application model; at the same time, the map can be of any origin.

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
      {:ok, %{cost: map.cost_value}}
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

## Use with other libraries

### Jason

JSON maps decoded with [Jason library](https://github.com/michalmuskala/jason/) 
are supported with both strings and atoms keys.

### Domo

To validate the types of the nested struct values, consider 
[Domo library](https://github.com/IvanRublev/Domo) that ensures struct's 
`t()` type and associated preconditions.

[//]: # (Documentation)

## Changelog

### 0.1.0
* Inintial release

## License

Copyright © 2021 Ivan Rublev

This project is licensed under the [MIT license](LICENSE).
