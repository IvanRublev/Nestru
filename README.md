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

It works with maps/structs of any shape and level of nesting. Highly configurable
by implementing `Nestru.Decoder` and `Nestru.Encoder` protocols for structs.

Useful for translating map keys to struct's fields named differently. 
Or to specify default values missing in the map and required by struct.

The library's primary purpose is to serialize a map coming from a JSON payload 
or an Erlang term; at the same time, the map can be of any origin.

The input map can have atom or binary keys. The library takes the binary key first 
and then the same-named atom key if the binary key is missing while decoding
the map.
The library generates maps with atom keys during the struct encode operation.

## Tour

<p align="center" class="hidden">
  <a href="https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FIvanRublev%2FNestru%2Fblob%2Fmaster%2FREADME.md">
    <img src="https://livebook.dev/badge/v1/blue.svg" alt="Run in Livebook" />
  </a>
</p>

Let's say we have an `Order` with a total field which is an instance of a `Total` struct.
And we want to serialize between an instance of `Order` and a map.

Firstly, let's derive `Nestru.Encoder` and `Nestru.Decoder` protocols 
and give a hint that the field `:total` should hold a value of `Total` struct
like the following:

```elixir
defmodule Order do
  @derive [Nestru.Encoder, {Nestru.Decoder, hint: %{total: Total}}]
  defstruct [:id, :total]
end

defmodule Total do
  @derive [Nestru.Encoder, Nestru.Decoder]
  defstruct [:sum]
end
```
```output
{:module, Total, <<70, 79, 82, 49, 0, 0, 8, ...>>, %Total{sum: nil}}
```

Secondly, we can encode the `Order` into the map like that:

```elixir
model = %Order{id: "A548", total: %Total{sum: 500}}
{:ok, map} = Nestru.encode(model)
```
```output
{:ok, %{id: "A548", total: %{sum: 500}}}
```

And decode the map back into the `Order` like the following:

```elixir
map = %{
  "id" => "A548",
  "total" => %{"sum" => 500}
}

{:ok, model} = Nestru.decode(map, Order)
```
```output
{:ok, %Order{id: "A548", total: %Total{sum: 500}}}
```

As you can see the data markup is in place, the `Total` struct is nested within the `Order` struct.

## A list of structs in a field

Let's add the `:items` field to `Order1` struct to hold a list of `LineItem`s 
and give a hint to `Nestru` on how to decode that field:

```elixir
defmodule Order1 do
  @derive {Nestru.Decoder, hint: %{total: Total, items: [LineItem]}}

  defstruct [:id, :items, :total]
end

defmodule LineItem do
  @derive Nestru.Decoder
  defstruct [:amount]
end
```
```output
{:module, LineItem, <<70, 79, 82, 49, 0, 0, 8, ...>>, %LineItem{amount: nil}}
```

Let's decode:

```elixir
map = %{
  "id" => "A548",
  "items" => [%{"amount" => 150}, %{"amount" => 350}],
  "total" => %{"sum" => 500}
}

{:ok, model} = Nestru.decode(map, Order1)
```
```output
{:ok,
 %Order1{
   id: "A548",
   items: [%LineItem{amount: 150}, %LineItem{amount: 350}],
   total: %Total{sum: 500}
 }}
```

Voilà, we have field values as nested structs 🎉

For the case when the list contains several structs of different types, please,
see the Serializing type-dependent fields section below.


## Date Time and URI

Let's say we have an `Order2` struct with some `URI` and `DateTime` fields in it. 
These attributes are structs in Elixir, at the same time they usually
kept as binary representations in a map.

`Nestru` supports conversion between binaries 
and structs, all we need to do is to implement the `Nestry.Encoder` 
and `Nestru.Decoder` protocols for these structs like the following:

```elixir
# DateTime
defimpl Nestru.Encoder, for: DateTime do
  def gather_fields_from_struct(struct, _context) do
    {:ok, DateTime.to_string(struct)}
  end
end

defimpl Nestru.Decoder, for: DateTime do
  def decode_fields_hint(_empty_struct, _context, value) do
    case DateTime.from_iso8601(value) do
      {:ok, date_time, _offset} -> {:ok, date_time}
      error -> error
    end
  end
end

# URI
defimpl Nestru.Encoder, for: URI do
  def gather_fields_from_struct(struct, _context) do
    {:ok, URI.to_string(struct)}
  end
end

defimpl Nestru.Decoder, for: URI do
  def decode_fields_hint(_empty_struct, _context, value) do
    URI.new(value)
  end
end
```
```output
{:module, Nestru.Decoder.URI, <<70, 79, 82, 49, 0, 0, 8, ...>>, {:decode_fields_hint, 3}}
```

`Order2` is defined like this:

```elixir
defmodule Order2 do
  @derive [Nestru.Encoder, {Nestru.Decoder, hint: %{date: DateTime, website: URI}}]
  defstruct [:id, :date, :website]
end
```
```output
{:module, Order2, <<70, 79, 82, 49, 0, 0, 8, ...>>, %Order2{id: nil, date: nil, website: nil}}
```

We can encode it to a map with binary fields like the following:

```elixir
order = %Order2{id: "B445", date: ~U[2024-03-15 22:42:03Z], website: URI.parse("https://www.example.com/?book=branch")}

{:ok, map} = Nestru.encode(order)
```
```output
{:ok, %{id: "B445", date: "2024-03-15 22:42:03Z", website: "https://www.example.com/?book=branch"}}
```

And decode it back:

```elixir
Nestru.decode(map, Order2)
```
```output
{:ok,
 %Order2{
   id: "B445",
   date: ~U[2024-03-15 22:42:03Z],
   website: %URI{
     scheme: "https",
     userinfo: nil,
     host: "www.example.com",
     port: 443,
     path: "/",
     query: "book=branch",
     fragment: nil
   }
 }}
```


## Error handling and path to the failed part of the map

Every implemented function of Nestru protocols can return `{error, message}` tuple 
in case of failure. When `Nestru` receives the error tuple, it stops conversion
and bypasses the error to the caller.

```elixir
defmodule Location do
  @derive {Nestru.Decoder, hint: %{street: Street}}
  defstruct [:street]
end

defmodule Street do
  @derive {Nestru.Decoder, hint: %{house: House}}
  defstruct [:house]
end

defmodule House do
  defstruct [:number]

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      if Nestru.has_key?(value, :number) do
        {:ok, %{}}
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

{:error, error} = Nestru.decode(map, Location)
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
    {Nestru.PreDecoder, translate: %{"cost_value" => :cost}},
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

Nestru.decode(map, Quote)
```
```output
{:ok, %Quote{cost: 1280}}
```

For more sophisticated key mapping you can implement 
the `gather_fields_for_decoding/3` function of `Nestru.PreDecoder` explicitly.

## Serializing type-dependent fields

To convert a struct with a field that can have the value of multiple struct types
into the map and back, the type of the field's value should be persisted. 
It's possible to do that like the following:

```elixir
defmodule BookCollection do
  defstruct [:name, :items]

  defimpl Nestru.Encoder do
    def gather_fields_from_struct(struct, _context) do
      items_kinds =
        Enum.map(struct.items, fn %module{} ->
          module
          |> Module.split()
          |> Enum.join(".")
        end)

      {:ok, %{name: struct.name, items: struct.items, items_kinds: items_kinds}}
    end
  end

  defimpl Nestru.Decoder do
    def decode_fields_hint(_empty_struct, _context, value) do
      items_kinds =
        Enum.map(value.items_kinds, fn module_string ->
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
```

Let's convert the nested struct into a map. The returned map gets 
extra `items_kinds` field with types information:

```elixir
alias BookCollection.{Book, Magazine}

collection = %BookCollection{
  name: "Duke of Norfolk's archive",
  items: [
    %Book{title: "The Spell in the Chasm"},
    %Magazine{issue: "Strange Hunt"}
  ]
}

{:ok, map} = Nestru.encode(collection)
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
{:ok, collection} = Nestru.decode(map, BookCollection)
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
The queries can be useful in `Nestru.PreDecoder.gather_fields_for_decoding/3`
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

### 1.0.0

* Convert structs to/from binaries for better serialization of `DateTime` and `URI` to/from strings
* Breaking changes in function names:
  * `Nestru.PreDecoder.gather_fields_from_map/3` has been renamed to `gather_fields_for_decoding/3`
  * `Nestru.Decoder.from_map_hint/1` has been renamed to `Nestru.Decoder.decode_fields_hint/1`
  * `Nestru.decode_from_map/3` has been renamed to `Nestru.decode/3`
  * `Nestru.encode_to_map/2` has been renamed to `Nestru.encode/2`
* The `Nestru.Decoder.decode_fields_hint/3` can now return a struct as a hint as `{:ok, %struct{}}`. 
  In this case `Nestru.decode/3` will return the struct as the decoded value.

### 0.3.3

* Fix the regress - make the decoding of an empty list return an empty list

### 0.3.2

* Return error from `decode_from_list_of_maps(!)/2/3` for non-list values

### 0.3.1

* Add `:only` and `:except` options for deriving of `Nestru.Encoder` protocol
* Add explicit `:translate` option for deriving of `Nestru.PreDecoder` protocol
* Add explicit `:hint` option for deriving of `Nestru.Decoder` protocol

### 0.3.0

* Rename `Nestru.PreDecoder.gather_fields_map/3` to `gather_fields_for_decoding/3`.
* Rename `Nestru.Encoder.encode/1` to `Nestru.Encoder.gather_fields_from_struct/2`
* Make `encode(!)/2` work only with structs and add `encode_to_list_of_maps(!)/2` for lists.
* Add context parameter to `encode_to_*` functions.

### 0.2.1

* Fix `decode(!)/2/3` to return the error for not a map value.

### 0.2.0

* Fix to ensure the module is loaded before checking if it's a struct
* Add `decode` and `encode` verbs to function names
* Support `[Module]` hint in the map returned from `decode_fields_hint` to decode the list of structs
* Support `%{one_key: :other_key}` mapping configuration for the `PreDecoder` protocol in `@derive` attribute.

### 0.1.1

* Add `has_key?/2` and `get/3` map functions that look up keys 
  both in a binary or an atom form.

### 0.1.0

* Initial release.

## License

Copyright © 2021 Ivan Rublev

This project is licensed under the [MIT license](LICENSE).
