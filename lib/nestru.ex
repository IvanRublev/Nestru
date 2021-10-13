defmodule Nestru do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("[//]: # (Documentation)\n")
             |> Enum.at(1)
             |> String.trim("\n")

  @doc """
  Creates a nested struct from the given map.

  The first argument is a map having key-value pairs. Supports both string
  and atom keys in the map.

  The second argument is a struct's module atom.

  The third argument is a context value to be passed to implemented
  functions of `Nestru.PreDecoder` and `Nestru.Decoder` protocols.

  To give a hint on how to decode nested struct values or a list of such values
  for the given field, implement `Nestru.Decoder` protocol for the struct.

  Function calls `struct/2` to build the struct's value.
  Keys in the map that don't exist in the struct are automatically discarded.
  """
  def from_map(map, struct_module, context \\ [])

  def from_map(%{} = map, struct_module, context) do
    case prepare_map(:warn, map, struct_module, context) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, map} ->
        {:ok, struct(struct_module, map)}

      {:error, %{} = map} ->
        {:error, format_get_in_keys(map)}

      {:invalid_hint_shape, %{message: {struct_module, value}} = error_map} ->
        {:error, %{error_map | message: invalid_hint_shape(struct_module, value)}}

      {:invalid_gather_fields_shape, struct_module, value} ->
        {:error, %{message: invalid_gather_fields_shape(struct_module, value)}}

      {:unexpected_item_value, key, value} ->
        {:error, %{message: invalid_item_value(struct_module, key, value)}}

      {:unexpected_item_function_return, key, fun, value} ->
        {:error, %{message: invalid_item_function_return_value(struct_module, key, fun, value)}}

      {:unexpected_atom_for_item_with_list, key, value} ->
        {:error, %{message: invalid_atom_for_item_with_list(struct_module, key, value)}}
    end
  end

  def from_map(map, _struct_module, _context) do
    map
  end

  @doc """
  Similar to `from_map/3` but checks if enforced struct's fields keys exist
  in the given map.

  Returns a struct or raises an error.
  """
  def from_map!(map, struct_module, context \\ [])

  def from_map!(%{} = map, struct_module, context) do
    case prepare_map(:raise, map, struct_module, context) do
      {:ok, nil} ->
        nil

      {:ok, map} ->
        struct!(struct_module, map)

      {:error, %{} = error_map} ->
        raise format_raise_message("map", error_map)

      {:invalid_hint_shape, %{message: {struct_module, value}}} ->
        raise invalid_hint_shape(struct_module, value)

      {:invalid_gather_fields_shape, struct_module, value} ->
        raise invalid_gather_fields_shape(struct_module, value)

      {:unexpected_item_value, key, value} ->
        raise invalid_item_value(struct_module, key, value)

      {:unexpected_item_function_return, key, fun, value} ->
        raise invalid_item_function_return_value(struct_module, key, fun, value)

      {:unexpected_atom_for_item_with_list, key, value} ->
        raise invalid_atom_for_item_with_list(struct_module, key, value)
    end
  end

  def from_map!(map, struct_module, _context) do
    raise """
    Can't shape #{inspect(struct_module)} because the given value \
    is not a map but #{inspect(map)}.\
    """
  end

  defp prepare_map(error_mode, map, struct_module, context) do
    struct_value = struct_module.__struct__()
    struct_info = {struct_value, struct_module}

    with {:ok, map} <- gather_fields_map(struct_info, map, context),
         {:ok, decode_hint} <- get_decode_hint(struct_info, map, context),
         {:ok, _shaped_fields} = ok <- shape_fields(error_mode, struct_info, decode_hint, map) do
      ok
    end
  end

  defp gather_fields_map(struct_info, map, context) do
    {struct_value, struct_module} = struct_info

    struct_value
    |> Nestru.PreDecoder.gather_fields_map(context, map)
    |> validate_fields_map(struct_module)
  end

  defp validate_fields_map({:ok, %{}} = ok, _struct_module),
    do: ok

  defp validate_fields_map({:error, message}, _struct_module),
    do: {:error, %{message: message}}

  defp validate_fields_map(value, struct_module),
    do: {:invalid_gather_fields_shape, struct_module, value}

  defp get_decode_hint(struct_info, map, context) do
    {struct_value, struct_module} = struct_info

    struct_value
    |> Nestru.Decoder.from_map_hint(context, map)
    |> validate_hint(struct_module)
  end

  defp validate_hint({:ok, hint} = ok, _struct_module) when is_nil(hint) or is_map(hint),
    do: ok

  defp validate_hint({:error, %{message: _}} = error, _struct_module),
    do: error

  defp validate_hint({:error, message}, _struct_module),
    do: {:error, %{message: message}}

  defp validate_hint(value, struct_module),
    do: {:invalid_hint_shape, %{message: {struct_module, value}}}

  defp shape_fields(_error_mode, _struct_info, nil = _decode_hint, _map) do
    {:ok, nil}
  end

  defp shape_fields(error_mode, struct_info, decode_hint, map) do
    {struct_value, struct_module} = struct_info
    struct_keys = struct_value |> Map.keys() |> List.delete(:__struct__)

    inform_unknown_keys(error_mode, decode_hint, struct_module, struct_keys)

    decode_hint = Map.take(decode_hint, struct_keys)
    kvi = decode_hint |> :maps.iterator() |> :maps.next()

    with {:ok, acc} <- shape_fields_recursively(error_mode, kvi, map) do
      as_is_keys = struct_keys -- Map.keys(decode_hint)

      fields =
        Enum.reduce(as_is_keys, %{}, fn key, taken_map ->
          if has_field_value?(map, key) do
            value = get_field_value(map, key)
            Map.put(taken_map, key, value)
          else
            taken_map
          end
        end)

      {:ok, Map.merge(fields, acc)}
    end
  end

  defp inform_unknown_keys(error_mode, map, struct_module, struct_keys) do
    if extra_key = List.first(Map.keys(map) -- struct_keys) do
      message = """
      The decoding hint value for key #{inspect(extra_key)} received from Nestru.Decoder.from_map_hint/3 \
      implemented for #{inspect(struct_module)} is unexpected because the struct hasn't a field with such key name.\
      """

      if error_mode == :raise do
        raise message
      else
        IO.warn(message)
      end
    end

    :ok
  end

  defp shape_fields_recursively(error_mode, kvi, map, acc \\ %{})

  defp shape_fields_recursively(_error_mode, :none = _kvi, _map, target_map) do
    {:ok, target_map}
  end

  defp shape_fields_recursively(error_mode, {key, fun, iterator}, map, target_map)
       when is_function(fun) do
    map_value = get_field_value(map, key)

    case fun.(map_value) do
      {:ok, updated_value} ->
        target_map = Map.put(target_map, key, updated_value)
        shape_fields_recursively(error_mode, :maps.next(iterator), map, target_map)

      {:error, %{message: _, path: _} = error_map} ->
        {:error, insert_to_path(error_map, key)}

      {:error, message} ->
        {:error, insert_to_path(%{message: message}, key)}

      value ->
        {:unexpected_item_function_return, key, fun, value}
    end
  end

  defp shape_fields_recursively(error_mode, {key, module, iterator}, map, target_map)
       when is_atom(module) do
    if function_exported?(module, :__struct__, 0) do
      result =
        case get_field_value(map, key) do
          [_ | _] ->
            {:unexpected_atom_for_item_with_list, key, module}

          nil ->
            {:ok, nil}

          map_value ->
            shape_nested_struct(error_mode, key, map_value, module)
        end

      case result do
        {:ok, shaped_value} ->
          target_map = Map.put(target_map, key, shaped_value)
          shape_fields_recursively(error_mode, :maps.next(iterator), map, target_map)

        error ->
          error
      end
    else
      {:unexpected_item_value, key, module}
    end
  end

  defp shape_fields_recursively(_error_mode, kvi, _map, _acc) do
    {key, value, _iterator} = kvi
    {:unexpected_item_value, key, value}
  end

  defp shape_nested_struct(error_mode, key, map_value, module) do
    shaped_value =
      if error_mode == :raise do
        from_map!(map_value, module)
      else
        from_map(map_value, module)
      end

    case shaped_value do
      struct when error_mode == :raise ->
        {:ok, struct}

      {:ok, _struct} = ok ->
        ok

      {:error, error_map} ->
        {:error, insert_to_path(error_map, key)}
    end
  end

  defp insert_to_path(error_map, key) do
    path =
      Enum.concat([
        List.wrap(key),
        Map.get(error_map, :path, [])
      ])

    Map.put(error_map, :path, path)
  end

  defp has_field_value?(map, key) do
    Map.has_key?(map, to_string(key)) or Map.has_key?(map, key)
  end

  defp get_field_value(map, key) do
    Map.get(map, to_string(key)) || Map.get(map, key)
  end

  defp invalid_gather_fields_shape(struct_module, value) do
    """
    Expected a {:ok, map} | {:error, term} value from Nestru.PreDecoder.gather_fields_map/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_hint_shape(struct_module, value) do
    """
    Expected a {:ok, nil | map} | {:error, term} value from Nestru.Decoder.from_map_hint/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_item_function_return_value(struct_module, key, fun, value) do
    """
    Expected {:ok, term}, {:error, %{message: term, path: list}}, or %{:error, term} \
    return value from the anonymous function for the key defined in the following \
    {:ok, %{#{inspect(key)} => #{inspect(fun)}}} tuple returned from Nestru.Decoder.from_map_hint/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_item_value(struct_module, key, value) do
    """
    Expected a struct's module atom or a function value for #{inspect(key)} key received \
    from Nestru.Decoder.from_map_hint/3 function implemented for #{inspect(struct_module)}, \
    received #{inspect(value)} instead.\
    """
  end

  defp invalid_atom_for_item_with_list(struct_module, key, value) do
    """
    Unexpected #{inspect(value)} value received for #{inspect(key)} key \
    from Nestru.Decoder.from_map_hint/3 function implemented for #{inspect(struct_module)}. \
    You can return &Nestru.from_list_of_maps(&1, #{inspect(value)}) as a hint \
    for list decoding.\
    """
  end

  @doc """
  Creates a map from the given nested struct.

  Casts each field's value to a map recursively, whether it is a struct or
  a list of structs.

  To give a hint to the function of how to generate a map, implement
  `Nestru.Encoder` protocol for the struct. That can be used to keep
  additional type information for the field that can have a value of various
  struct types.
  """
  def to_map(struct) do
    case cast_to_map(struct) do
      {:invalid_hint_shape, %{message: {struct_module, value}} = error_map} ->
        {:error, %{error_map | message: invalid_to_map_value_message(struct_module, value)}}

      {:ok, _value} = ok ->
        ok

      {:error, map} ->
        {:error, format_get_in_keys(map)}
    end
  end

  @doc """
  Similar to `to_map/1`.

  Returns a map or raises an error.
  """
  def to_map!(struct) do
    case cast_to_map(struct) do
      {:ok, map} ->
        map

      {:invalid_hint_shape, %{message: {struct_module, value}}} ->
        raise invalid_to_map_value_message(struct_module, value)

      {:error, error_map} ->
        raise format_raise_message("struct", error_map)
    end
  end

  defp cast_to_map(struct, kvi \\ nil, acc \\ {[], %{}})

  defp cast_to_map(%module{} = struct, _kvi, {path, _target_map} = acc) do
    case struct |> Nestru.Encoder.to_map() |> validate_hint(module) do
      {:ok, map} -> cast_to_map(map, nil, acc)
      {tag, %{} = map} -> {tag, Map.put(map, :path, path)}
    end
  end

  defp cast_to_map([_ | _] = list, _kvi, {path, _target_map} = _acc) do
    list
    |> reduce_via_cast_to_map(path)
    |> maybe_ok_reverse()
  end

  defp cast_to_map(value, _kvi, _acc) when not is_map(value) do
    {:ok, value}
  end

  defp cast_to_map(map, nil, acc) do
    kvi =
      map
      |> :maps.iterator()
      |> :maps.next()

    cast_to_map(map, kvi, acc)
  end

  defp cast_to_map(_map, :none, {_path, target_map} = _acc) do
    {:ok, target_map}
  end

  defp cast_to_map(map, {key, value, iterator}, {path, target_map}) do
    with {:ok, casted_value} <- cast_to_map(value, nil, {[key | path], %{}}) do
      target_map = Map.put(target_map, key, casted_value)
      kvi = :maps.next(iterator)
      cast_to_map(map, kvi, {path, target_map})
    end
  end

  defp reduce_via_cast_to_map(list, path) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, idx}, acc ->
      case cast_to_map(item, nil, {[], %{}}) do
        {:ok, casted_item} ->
          {:cont, [casted_item | acc]}

        {:error, error_map} ->
          keys_list =
            path
            |> Enum.reverse()
            |> Enum.concat([idx])

          {:halt, {:error, insert_to_path(error_map, keys_list)}}
      end
    end)
  end

  defp maybe_ok_reverse([_ | _] = list), do: {:ok, Enum.reverse(list)}
  defp maybe_ok_reverse([]), do: {:ok, []}
  defp maybe_ok_reverse({:error, _map} = error), do: error

  defp invalid_to_map_value_message(struct_module, value) do
    """
    Expected a {:ok, nil | map} | {:error, term} value from Nestru.Encoder.to_map/1 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp format_get_in_keys(map) do
    keys =
      map
      |> Map.get(:path, [])
      |> Enum.map(&to_access_fun/1)

    Map.put(map, :get_in_keys, keys)
  end

  defp to_access_fun(key) when is_atom(key), do: Access.key!(key)
  defp to_access_fun(key) when is_integer(key), do: Access.at!(key)
  defp to_access_fun(key) when is_function(key), do: key

  defp format_raise_message(object, map) do
    keys =
      map
      |> Map.get(:path, [])
      |> Enum.map(&to_access_string/1)
      |> Enum.join(", ")

    """
    #{stringify(map.message)}

    See details by calling get_in/2 with the #{object} and the following keys: [#{keys}]\
    """
  end

  defp to_access_string(key) when is_atom(key), do: "Access.key!(#{inspect(key)})"
  defp to_access_string(key) when is_integer(key), do: "Access.at!(#{key})"
  defp to_access_string(key) when is_binary(key), do: key

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: inspect(value)

  @doc """
  Creates a list of nested structs from the given list of maps.

  The first argument is a list of maps.

  If the second argument is a struct's module atom, then the function calls
  the `from_map/3` on each input list item.

  If the second argument is a list of struct module atoms, the function
  calls the `from_map/3` function on each input list item with the module atom
  taken at the same index of the second list.
  In this case, both arguments should be of equal length.

  The third argument is a context value to be passed to implemented
  functions of `Nestru.PreDecoder` and `Nestru.Decoder` protocols.

  The function returns a list of structs or the first error from `from_map/3`
  function.
  """
  def from_list_of_maps(list, struct_atoms, context \\ [])

  def from_list_of_maps([_ | _] = list, struct_atoms, context) do
    list
    |> reduce_via_from_map(struct_atoms, context)
    |> maybe_ok_reverse()
  end

  def from_list_of_maps(list, _struct_atoms, _context) do
    {:ok, list}
  end

  @doc """
  Similar to `from_list_of_maps/2` but checks if enforced struct's fields keys
  exist in the given maps.

  Returns a struct or raises an error.
  """
  def from_list_of_maps!(list, struct_atoms, context \\ [])

  def from_list_of_maps!([_ | _] = list, struct_atoms, context) do
    case list |> reduce_via_from_map(struct_atoms, context) |> maybe_ok_reverse() do
      {:ok, list} -> list
      {:error, %{message: message}} -> raise message
    end
  end

  def from_list_of_maps!(list, _struct_atoms, _context) do
    list
  end

  defp reduce_via_from_map(list, [_ | _] = struct_atoms, context)
       when length(list) == length(struct_atoms) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, idx}, acc ->
      struct_module = Enum.at(struct_atoms, idx)

      case from_map(item, struct_module, context) do
        {:ok, casted_item} ->
          {:cont, [casted_item | acc]}

        {:error, map} ->
          {:halt, {:error, insert_to_path(map, idx)}}
      end
    end)
  end

  defp reduce_via_from_map(list, struct_atoms, context) when is_atom(struct_atoms) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, idx}, acc ->
      case from_map(item, struct_atoms, context) do
        {:ok, casted_item} ->
          {:cont, [casted_item | acc]}

        {:error, map} ->
          {:halt, {:error, insert_to_path(map, idx)}}
      end
    end)
  end

  defp reduce_via_from_map(list, struct_atoms, _context) do
    {:error,
     %{
       message: """
       The map's list length (#{length(list)}) is expected to be equal to \
       the struct module atoms list length (#{length(struct_atoms)}).\
       """
     }}
  end
end
