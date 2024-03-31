defmodule Nestru do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- Documentation -->\n")
             |> Enum.at(1)
             |> String.trim("\n")

  @doc """
  Decodes a map or a binary into the given struct.

  The first argument is a map having key-value pairs which supports both string
  and atom keys. Or a binary representation, f.e. date time in ISO 8601 format.

  The second argument is a struct's module atom.

  The third argument is a context value to be passed to implemented
  functions of `Nestru.PreDecoder` and `Nestru.Decoder` protocols.

  To give a hint on how to decode nested struct values or a list of such values
  for the given field, implement `Nestru.Decoder` protocol for the struct.

  Function calls `struct/2` to build the struct's value.
  If given a map, keys that don't exist in the struct are automatically discarded.
  """
  def decode(value, struct_module, context \\ [])

  def decode(value, struct_module, context) when is_map(value) or is_binary(value) do
    case prepare_map(:warn, value, struct_module, context) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, %_struct_module{} = struct} ->
        {:ok, struct}

      {:ok, map} ->
        {:ok, struct(struct_module, map)}

      {:error, %{} = map} ->
        {:error, format_paths(map)}

      {:invalid_hint_shape, %{message: {struct_module, value}} = error_map} ->
        {:error, %{error_map | message: invalid_decode_fields_hint_shape(struct_module, value)}}

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

  def decode(value, struct_module, _context) do
    {:error, %{message: invalid_input_to_decode(struct_module, value)}}
  end

  @doc """
  Similar to `decode/3` but checks if enforced struct's fields keys exist after decoding.

  Returns a struct or raises an error.
  """
  def decode!(value, struct_module, context \\ [])

  def decode!(value, struct_module, context) when is_map(value) or is_binary(value) do
    case prepare_map(:raise, value, struct_module, context) do
      {:ok, nil} ->
        nil

      {:ok, %_struct_module{} = value} ->
        value

      {:ok, map} ->
        struct!(struct_module, map)

      {:error, %{} = error_map} ->
        raise format_raise_message("map", error_map)

      {:invalid_hint_shape, %{message: {struct_module, value}}} ->
        raise invalid_decode_fields_hint_shape(struct_module, value)

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

  def decode!(value, struct_module, _context) do
    raise invalid_input_to_decode(struct_module, value)
  end

  defp prepare_map(error_mode, value, struct_module, context) do
    struct_value = struct_module.__struct__()
    struct_info = {struct_value, struct_module}

    with {:ok, maybe_map} <- gather_fields_for_decoding(struct_info, value, context),
         {:ok, decode_hint} <- get_decode_hint(struct_info, maybe_map, context),
         {:ok, _shaped_fields} = ok <-
           shape_fields(error_mode, struct_info, decode_hint, maybe_map) do
      ok
    end
  end

  defp gather_fields_for_decoding(struct_info, value, context) do
    {struct_value, struct_module} = struct_info

    struct_value
    |> Nestru.PreDecoder.gather_fields_for_decoding(context, value)
    |> validate_fields_map(struct_module)
  end

  defp validate_fields_map({:ok, %{}} = ok, _struct_module),
    do: ok

  defp validate_fields_map({:ok, binary} = ok, _struct_module) when is_binary(binary),
    do: ok

  defp validate_fields_map({:error, message}, _struct_module),
    do: {:error, %{message: message}}

  defp validate_fields_map(value, struct_module),
    do: {:invalid_gather_fields_shape, struct_module, value}

  defp get_decode_hint(struct_info, map, context) do
    {struct_value, struct_module} = struct_info

    struct_value
    |> Nestru.Decoder.decode_fields_hint(context, map)
    |> validate_hint(struct_module)
  end

  defp validate_hint({:ok, hint} = ok, _struct_module)
       when is_nil(hint) or (is_map(hint) and not is_struct(hint)) or is_binary(hint),
       do: ok

  defp validate_hint({:ok, %struct_module{}} = ok, struct_module),
    do: ok

  defp validate_hint({:error, %{message: _}} = error, _struct_module),
    do: error

  defp validate_hint({:error, message}, _struct_module),
    do: {:error, %{message: message}}

  defp validate_hint(value, struct_module),
    do: {:invalid_hint_shape, %{message: {struct_module, value}}}

  defp shape_fields(_error_mode, _struct_info, nil = _decode_hint, _maybe_map) do
    {:ok, nil}
  end

  defp shape_fields(_error_mode, {_, struct_module}, %struct_module{} = decode_hint, _maybe_map) do
    {:ok, decode_hint}
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
          if has_key?(map, key) do
            value = get(map, key)
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
      The decoding hint value for key #{inspect(extra_key)} received from Nestru.Decoder.decode_fields_hint/3 \
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

  defp shape_fields_recursively(error_mode, {key, [module], iterator}, map, target_map)
       when is_atom(module) do
    shape_fields_recursively(
      error_mode,
      {key, &__MODULE__.decode_from_list_of_maps(&1, module), iterator},
      map,
      target_map
    )
  end

  defp shape_fields_recursively(error_mode, {key, fun, iterator}, map, target_map)
       when is_function(fun) do
    map_value = get(map, key)

    case fun.(map_value) do
      {:ok, updated_value} ->
        target_map = Map.put(target_map, key, updated_value)
        shape_fields_recursively(error_mode, :maps.next(iterator), map, target_map)

      {:error, %{message: _, path: path} = error_map} = error ->
        validate_path!(path, error, fun)
        {:error, insert_to_path(error_map, key, map)}

      {:error, message} ->
        {:error, insert_to_path(%{message: message}, key, map)}

      value ->
        {:unexpected_item_function_return, key, fun, value}
    end
  end

  defp shape_fields_recursively(error_mode, {key, module, iterator}, map, target_map)
       when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) do
      result =
        case get(map, key) do
          [_ | _] ->
            {:unexpected_atom_for_item_with_list, key, module}

          nil ->
            {:ok, nil}

          map_value ->
            shape_nested_struct(error_mode, map, key, map_value, module)
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

  defp shape_nested_struct(error_mode, map, key, map_value, module) do
    shaped_value =
      if error_mode == :raise do
        decode!(map_value, module)
      else
        decode(map_value, module)
      end

    case shaped_value do
      struct when error_mode == :raise ->
        {:ok, struct}

      {:ok, _struct} = ok ->
        ok

      {:error, error_map} ->
        {:error, insert_to_path(error_map, key, map)}
    end
  end

  defp validate_path!(path, error, fun) do
    unless Enum.all?(path, &(not is_nil(&1) and (is_atom(&1) or is_binary(&1) or is_number(&1)))) do
      raise """
      Error path can contain only not nil atoms, binaries or integers. \
      Error is #{inspect(error)}, received from function #{inspect(fun)}.\
      """
    end
  end

  defp insert_to_path(error_map, key, map_value) do
    key = resolve_key(map_value, key)
    insert_to_path(error_map, key)
  end

  defp insert_to_path(error_map, key_or_idx) do
    path =
      Enum.concat([
        List.wrap(key_or_idx),
        Map.get(error_map, :path, [])
      ])

    Map.put(error_map, :path, path)
  end

  defp resolve_key(map, key) do
    existing_key(map, key) ||
      (is_binary(key) && apply_atom_key(key, nil, &existing_key(map, &1))) ||
      (is_atom(key) && existing_key(map, to_string(key))) || key
  end

  defp apply_atom_key(string, default, fun) do
    try do
      fun.(String.to_existing_atom(string))
    rescue
      ArgumentError -> default
    end
  end

  defp existing_key(map, key) do
    if Map.has_key?(map, key), do: key
  end

  defp invalid_input_to_decode(struct_module, value) do
    """
    Expected a map or a binary value received #{inspect(value)} instead. \
    Can't convert it to a #{inspect(struct_module)} struct.\
    """
  end

  defp invalid_gather_fields_shape(struct_module, value) do
    """
    Expected a {:ok, map | binary} | {:error, term} value from Nestru.PreDecoder.gather_fields_for_decoding/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_decode_fields_hint_shape(struct_module, value) do
    module_name = struct_module |> Module.split() |> Enum.join(".")

    """
    Expected a {:ok, nil | map | %#{module_name}{}} | {:error, term} value from Nestru.Decoder.decode_fields_hint/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_item_function_return_value(struct_module, key, fun, value) do
    """
    Expected {:ok, term}, {:error, %{message: term, path: list}}, or %{:error, term} \
    return value from the anonymous function for the key defined in the following \
    {:ok, %{#{inspect(key)} => #{inspect(fun)}}} tuple returned from Nestru.Decoder.decode_fields_hint/3 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp invalid_item_value(struct_module, key, value) do
    """
    Expected a struct's module atom, [struct_module_atom], or a function value for #{inspect(key)} key received \
    from Nestru.Decoder.decode_fields_hint/3 function implemented for #{inspect(struct_module)}, \
    received #{inspect(value)} instead.\
    """
  end

  defp invalid_atom_for_item_with_list(struct_module, key, value) do
    """
    Unexpected #{inspect(value)} value received for #{inspect(key)} key \
    from Nestru.Decoder.decode_fields_hint/3 function implemented for #{inspect(struct_module)}. \
    You can return &Nestru.decode_from_list_of_maps(&1, #{inspect(value)}) as a hint \
    for list decoding.\
    """
  end

  @doc """
  Returns whether the given key exists in the given map as a binary or as an atom.
  """
  def has_key?(map, key) when is_binary(key) do
    Map.has_key?(map, key) or apply_atom_key(key, false, &Map.has_key?(map, &1))
  end

  def has_key?(map, key) when is_atom(key) do
    Map.has_key?(map, key) or Map.has_key?(map, to_string(key))
  end

  @doc """
  Gets the value for a specific key in map. Lookups a binary then an atom key.

  If key is present in map then its value value is returned. Otherwise, default is returned.

  If default is not provided, nil is used.
  """
  def get(map, key, default \\ nil)

  def get(map, key, default) when is_binary(key) do
    Map.get(map, key, apply_atom_key(key, default, &Map.get(map, &1, default)))
  end

  def get(map, key, default) when is_atom(key) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  @doc """
  Encodes the given struct into a map.

  The first argument is a struct value to be encoded into map.

  Encodes each field's value recursively when it is a struct or
  a list of structs.

  The second argument is a context to be passed to `Nestru.Encoder` protocol
  function.

  To insert additional fields or rename or drop existing ones before encoding
  into map, implement `Nestru.Encoder` protocol for the struct.
  That can be used to keep additional type information for the field that can
  have a value of various value types.
  """
  def encode(struct, context \\ nil)

  def encode(%_{} = struct, context) do
    case cast_to_map(struct, context) do
      {:invalid_hint_shape, %{message: {struct_module, value}} = error_map} ->
        {:error, %{error_map | message: invalid_to_map_value_message(struct_module, value)}}

      {:ok, _value} = ok ->
        ok

      {:error, map} ->
        {:error, format_paths(map)}
    end
  end

  def encode(value, _context) do
    raise expected_struct_value("encode/1", value, "encode_to_list_of_maps/1")
  end

  @doc """
  Similar to `encode/1`.

  Returns a map or raises an error.
  """
  def encode!(struct, context \\ nil)

  def encode!(%_{} = struct, context) do
    case cast_to_map(struct, context) do
      {:ok, map} ->
        map

      {:invalid_hint_shape, %{message: {struct_module, value}}} ->
        raise invalid_to_map_value_message(struct_module, value)

      {:error, error_map} ->
        raise format_raise_message("struct", error_map)
    end
  end

  def encode!(value, _context) do
    raise expected_struct_value("encode!/1", value, "encode_to_list_of_maps!/1")
  end

  defp cast_to_map(struct, context, kvi \\ nil, acc \\ {[], %{}})

  defp cast_to_map(%module{} = struct, context, _kvi, {path, _target_map} = acc) do
    case struct |> Nestru.Encoder.gather_fields_from_struct(context) |> validate_hint(module) do
      {:ok, map} -> cast_to_map(map, context, nil, acc)
      {tag, %{} = map} -> {tag, Map.put(map, :path, path)}
    end
  end

  defp cast_to_map([_ | _] = list, context, _kvi, {path, _target_map} = _acc) do
    list
    |> reduce_via_cast_to_map(context, path)
    |> maybe_ok_reverse()
  end

  defp cast_to_map(value, _context, _kvi, _acc) when not is_map(value) do
    {:ok, value}
  end

  defp cast_to_map(map, context, nil, acc) do
    kvi =
      map
      |> :maps.iterator()
      |> :maps.next()

    cast_to_map(map, context, kvi, acc)
  end

  defp cast_to_map(_map, _context, :none, {_path, target_map} = _acc) do
    {:ok, target_map}
  end

  defp cast_to_map(map, context, {key, value, iterator}, {path, target_map}) do
    with {:ok, casted_value} <- cast_to_map(value, context, nil, {[key | path], %{}}) do
      target_map = Map.put(target_map, key, casted_value)
      kvi = :maps.next(iterator)
      cast_to_map(map, context, kvi, {path, target_map})
    end
  end

  defp reduce_via_cast_to_map(list, context, path) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, idx}, acc ->
      case cast_to_map(item, context, nil, {[], %{}}) do
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
    Expected a {:ok, nil | map | binary} | {:error, term} value from Nestru.Encoder.gather_fields_from_struct/2 \
    function implemented for #{inspect(struct_module)}, received #{inspect(value)} instead.\
    """
  end

  defp expected_struct_value(fun_name, value, list_fun_name) do
    """
    #{fun_name} expects a struct as input value, received #{inspect(value)} instead.
    Use #{list_fun_name} to encode a list of structs to list of maps.\
    """
  end

  @doc """
  Encodes the given list of structs into a list of maps.

  Calls `encode/2` for each struct in the list. The `Nestru.Encoder`
  protocol should be implemented for each struct module.

  The function returns a list of maps or the first error from `encode/2` function.
  """
  def encode_to_list_of_maps(list, context \\ nil) do
    return_value =
      list
      |> Enum.with_index()
      |> Enum.reduce_while([], fn {struct, idx}, acc ->
        case encode(struct, context) do
          {:ok, map} ->
            {:cont, [map | acc]}

          {:error, map} ->
            {:halt, {:error, format_paths(insert_to_path(map, idx))}}
        end
      end)

    if is_list(return_value) do
      {:ok, Enum.reverse(return_value)}
    else
      return_value
    end
  end

  @doc """
  Similar to `encode_to_list_of_maps/2`

  Returns list of maps or raises an error.
  """
  def encode_to_list_of_maps!(list, context \\ nil) do
    case encode_to_list_of_maps(list, context) do
      {:ok, list_of_maps} ->
        list_of_maps

      {:invalid_hint_shape, %{message: {struct_module, value}}} ->
        raise invalid_to_map_value_message(struct_module, value)

      {:error, error_map} ->
        raise format_raise_message("list", error_map)
    end
  end

  defp format_paths(map) do
    keys =
      map
      |> Map.get(:path, [])
      |> Enum.map(&to_access_fun/1)

    Map.put(map, :get_in_keys, keys)
  end

  defp to_access_fun(key) when is_atom(key) or is_binary(key), do: Access.key!(key)
  defp to_access_fun(key) when is_integer(key), do: Access.at!(key)

  defp format_raise_message(object, map) do
    keys =
      map
      |> Map.get(:path, [])
      |> Enum.map_join(", ", &to_access_string/1)

    """
    #{stringify(map.message)}

    See details by calling get_in/2 with the #{object} and the following keys: [#{keys}]\
    """
  end

  defp to_access_string(key) when is_atom(key) or is_binary(key),
    do: "Access.key!(#{inspect(key)})"

  defp to_access_string(key) when is_integer(key),
    do: "Access.at!(#{key})"

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: inspect(value)

  @doc """
  Decodes a list of maps into the list of the given struct values.

  The first argument is a list.

  If the second argument is a struct's module atom, then the function calls
  the `decode/3` on each input list item.

  If the second argument is a list of struct module atoms, the function
  calls the `decode/3` function on each input list item with the module atom
  taken at the same index of the second list.
  In this case, both arguments should be of equal length.

  The third argument is a context value to be passed to implemented
  functions of `Nestru.PreDecoder` and `Nestru.Decoder` protocols.

  The function returns a list of structs or the first error from `decode/3`
  function.
  """
  def decode_from_list_of_maps(list, struct_atoms, context \\ [])

  def decode_from_list_of_maps(list, struct_atoms, context) when is_list(list) do
    list
    |> reduce_via_from_map(struct_atoms, context)
    |> maybe_ok_reverse()
  end

  def decode_from_list_of_maps(list, _struct_atoms, _context) do
    {:error, %{message: expected_list_value(list)}}
  end

  @doc """
  Similar to `decode_from_list_of_maps/2` but checks if enforced struct's fields keys
  exist in the given maps.

  Returns a struct or raises an error.
  """
  def decode_from_list_of_maps!(list, struct_atoms, context \\ [])

  def decode_from_list_of_maps!(list, struct_atoms, context) when is_list(list) do
    case list |> reduce_via_from_map(struct_atoms, context) |> maybe_ok_reverse() do
      {:ok, list} -> list
      {:error, %{message: message}} -> raise message
    end
  end

  def decode_from_list_of_maps!(list, _struct_atoms, _context) do
    raise expected_list_value(list)
  end

  defp reduce_via_from_map(list, [_ | _] = struct_atoms, context)
       when length(list) == length(struct_atoms) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {item, idx}, acc ->
      struct_module = Enum.at(struct_atoms, idx)

      case decode(item, struct_module, context) do
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
      case decode(item, struct_atoms, context) do
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

  defp expected_list_value(value) do
    """
    The first argument should be a list. Got #{inspect(value)} instead.\
    """
  end
end
