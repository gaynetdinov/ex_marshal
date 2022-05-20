defmodule ExMarshal.Decoder do
  alias ExMarshal.Errors.DecodeError

  def decode(<<_major::1-bytes, _minor::1-bytes, value::binary>>, opts \\ []) do
    initial_state = %{
      links: %{},
      references: %{locked: false, first_call: true}
    }

    {value, _rest, _state} = decode_element(value, initial_state)

    value
  end

  defp decode_element(<<data_type::1-bytes, value::binary>>, state) do
    case data_type do
      "0" ->
        {nil, value, state}
      "T" ->
        {true, value, state}
      "F" ->
        {false, value, state}
      "i" ->
        decode_fixnum(value, state)
      "I" ->
        decode_ivar(value, state)
      "\"" ->
        decode_raw_string(value, state)
      ":" ->
        decode_symbol(value, state)
      ";" ->
        decode_linked_symbol(value, state)
      "f" ->
        decode_float(value, state)
      "u" ->
        decode_big_decimal(value, state)
      "l" ->
        decode_bignum(value, state)
      "[" ->
        state =
          if state.references.first_call do
            put_in(state.references.first_call, false)
          else
            lock_references_state(state)
          end

        decode_array(value, state)
      "{" ->
        state =
          if state.references.first_call do
            put_in(state.references.first_call, false)
          else
            lock_references_state(state)
          end

        decode_hash(value, state)
      "@" ->
        decode_reference(value, state)
      "U" ->
        decode_user_object(value, state)
      symbol ->
        if nullify_objects?() do
          {nil, value, state}
        else
          raise DecodeError, reason: {:not_supported, symbol}
        end
    end
  end

  defp decode_fixnum(<<value::binary>>, state) do
    <<fixnum_type::8, fixnum_data::binary>> = value

    case fixnum_type do
      0 -> {0, fixnum_data, state}
      v when v >= 6 and v <= 127 ->
        <<fixnum::signed-little-integer-size(8)>> = <<v>>

        {fixnum - 5, fixnum_data, state}
      v when v >= 128 and v <= 250 ->
        <<fixnum::signed-little-integer-size(8)>> = <<v>>

        {fixnum + 5, fixnum_data, state}
      1 ->
        <<fixnum::8, rest::binary>> = fixnum_data

        {fixnum, rest, state}
      255 ->
        <<value::size(1)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(16)>> = <<value::binary, 255>>

        {fixnum, rest, state}
      2 ->
        <<value::size(2)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(24)>> = <<value::binary, 0>>

        {fixnum, rest, state}
      254 ->
        <<value::size(2)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(24)>> = <<value::binary, 255>>

        {fixnum, rest, state}
      3 ->
        <<value::size(3)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(32)>> = <<value::binary, 0>>

        {fixnum, rest, state}
      253 ->
        <<value::size(3)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(24)>> = <<value::binary>>

        {fixnum, rest, state}
      4 ->
        <<value::size(4)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(32)>> = <<value::binary>>

        {fixnum, rest, state}
      252 ->
        <<value::size(4)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(32)>> = <<value::binary>>

        {fixnum, rest, state}
    end
  end

  # Raw strings are wrapped into ivars. Currently only string ivars are
  # supported, so decoding an ivar equals to decoding a string.
  #
  # _meta is encoding value, don't know if I need this information here.
  defp decode_ivar(<<34, value::binary>>, state) do
    decode_string(value, state)
  end

  defp decode_ivar(<<_::8, value::binary>>, state) do
    if nullify_objects?() do
      {nil, value, state}
    else
      raise DecodeError, reason: {:ivar_string_only, value}
    end
  end

  defp decode_string(<<value::binary>>, state) do
    {str_bytes, value, state} = decode_fixnum(value, state)

    <<str::size(str_bytes)-bytes, rest::binary>> = value
    <<6, delimiter::8, rest::binary>> = rest

    case delimiter do
      58 ->
        <<enc_size::8, rest::binary>> = rest
        {enc_size, _, state} = decode_fixnum(<<enc_size>>, state)

        case enc_size do
          1 -> # utf8 or ascii encoding <<69, 84>> or <<69, 70>>
            <<enc_symbol::8, _meta::8, rest::binary>> = rest

            state = update_references(str, state)
            state = update_links_state(state, enc_symbol)

            {str, rest, state}
          x ->
            <<_encoding_word::size(x)-bytes, 34, encoding_name_size::8, rest::binary>> = rest
            {encoding_name_size, _, state} = decode_fixnum(<<encoding_name_size>>, state)

            <<enc_name::size(encoding_name_size)-bytes, rest::binary>> = rest

            state = update_references(str, state)
            state = update_links_state(state, enc_name)

            {str, rest, state}
        end
      59 -> # string encoding can be encoded as a reference of existing symbol
        <<_meta::8, _::8, rest::binary>> = rest
        state = update_references(str, state)

        {str, rest, state}
    end
  end

  defp decode_raw_string(<<str_length::8, value::binary>>, state) do
    {str_bytes, _, state} = decode_fixnum(<<str_length>>, state)
    <<value::size(str_bytes)-bytes, rest::binary>> = value

    {value, rest, state}
  end

  defp decode_linked_symbol(<<link::8, rest::binary>>, state) do
    {link, _rest, state} = decode_fixnum(<<link>>, state)

    {state.links[link], rest, state}
  end

  defp decode_symbol(<<symbol_length::8, value::binary>>, state) do
    {symbol_bytes, _, state} = decode_fixnum(<<symbol_length>>, state)

    <<value::size(symbol_bytes)-bytes, rest::binary>> = value
    atom_value = String.to_atom(value)

    state = update_links_state(state, atom_value)

    {atom_value, rest, state}
  end

  defp decode_float(<<value::binary>>, state) do
    {float_str, rest, state} = decode_raw_string(value, state)
    {float_value, _} = Float.parse(float_str)

    state = update_references(float_value, state)

    {float_value, rest, state}
  end

  defp decode_big_decimal(<<58, _::8, _str::size(10)-bytes, value::binary>>, state) do
    {decimal_str, rest, state} = decode_raw_string(value, state)
    [_significant_digits, decimal_value] = String.split(decimal_str, ":")

    decoded_big_decimal = Decimal.new(decimal_value)
    state = update_references(decoded_big_decimal, state)

    {decoded_big_decimal, rest, state}
  end

  defp decode_bignum(<<sign::1-bytes, size_byte::8, value::binary>>, state) do
    {size, _, state} = decode_fixnum(<<size_byte>>, state)
    size = size * 2 * 8

    <<bignum::native-integer-size(size), rest::binary>> = value

    if sign == "+" do
      state = update_references(bignum, state)
      {bignum, rest, state}
    else
      bignum = bignum * -1
      state = update_references(bignum, state)

      {bignum, rest, state}
    end
  end

  defp decode_array(value, 0, acc, state) do
    decoded_array = Enum.reverse(acc)

    state = update_references(decoded_array, state)
    state = unlock_references_state(state)

    {decoded_array, value, state}
  end

  defp decode_array(value, size, acc, state) do
    {element, rest, state} = decode_element(value, state)
    decode_array(rest, size - 1, [element | acc], state)
  end

  defp decode_array(<<0>>, state), do: {[], <<>>, state}

  defp decode_array(<<value::binary>>, state) do
    {size, rest, state} = decode_fixnum(value, state)
    decode_array(rest, size, [], state)
  end

  defp decode_hash(value, 0, acc, state) do
    decoded_hash = Enum.reverse(acc) |> Enum.into(%{})

    state = update_references(decoded_hash, state)
    state = unlock_references_state(state)

    {decoded_hash, value, state}
  end

  defp decode_hash(value, size, acc, state) do
    {key, rest, state} = decode_element(value, state)
    {value, rest, state} = decode_element(rest, state)

    decode_hash(rest, size - 1, [{key, value} | acc], state)
  end

  defp decode_hash(<<0>>, state), do: {%{}, <<>>, state}

  defp decode_hash(<<value::binary>>, state) do
    {size, rest, state} = decode_fixnum(value, state)

    decode_hash(rest, size, [], state)
  end

  defp decode_reference(<<reference::8, rest::binary>>, state) do
    {reference, _rest, state} = decode_fixnum(<<reference>>, state)

    {state.references[reference], rest, state}
  end

  defp decode_user_object(<<?:, rest::binary>>, state) do
    {class_name, rest, state} = decode_symbol(rest, state)
    {attributes, rest, state} = decode_element(rest, state)

    {{class_name, attributes}, rest, state}
  end

  defp update_references(value, state) do
    if state.references.locked do
      state
    else
      references_count =
        if is_nil(state.references[:count]) do
          1
        else
          state.references.count + 1
        end

      references_state = Map.put(state.references, :count, references_count)
      references_state = Map.put(references_state, references_count, value)

      %{state | references: references_state}
    end
  end

  defp lock_references_state(%{references: %{locked: true}} = state) do
    state
  end

  defp lock_references_state(%{references: %{locked: false}} = state) do
    put_in(state.references.locked, true)
  end

  defp unlock_references_state(state) do
    put_in(state.references.locked, false)
  end

  defp update_links_state(state, value) do
    links_count =
      if state.links[:count] do
        state.links.count + 1
      else
        0
      end

    state
    |> put_in([:links, :count], links_count)
    |> put_in([:links, links_count], value)
  end

  defp nullify_objects? do
    Application.get_env(:ex_marshal, :nullify_objects, false)
  end
end
