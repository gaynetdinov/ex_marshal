defmodule ExMarshal.Decoder do
  def decode(<<_major::1-bytes, _minor::1-bytes, value::binary>>) do
    case decode_element(value, %{}) do
      {value, _rest, _state} -> value
      # _ -> raise
    end
  end

  defp decode_element(<<data_type::1-bytes, value::binary>>, state) do
    case data_type do
      "0" -> {nil, nil, nil}
      "T" -> {true, nil, nil}
      "F" -> {false, nil, nil}
      "i" -> decode_fixnum(value, state)
      "I" -> decode_ivar(value, state)
      ":" -> decode_symbol(value, state)
      ";" -> decode_linked_symbol(value, state)
      "f" -> decode_float(value, state)
      "u" -> decode_big_decimal(value, state)
      "l" -> decode_bignum(value, state)
      "[" -> decode_array(value, state)
      "{" -> decode_hash(value, state)
    end
  end

  # Small integers, i.e. -123..122
  defp decode_fixnum(<<value::binary>>, state) do
    <<fixnum_type::8, fixnum_data::binary>> = value

    case fixnum_type do
      0 -> {0, fixnum_data, state}
      v when v >= 6 and v <= 122 ->
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
  defp decode_ivar(<<ivar_type::8, value::binary>>, state) do
    case ivar_type do
      34 -> decode_string(value, state)
      _ -> raise ExMarshal.DecodeError, reason: {:ivar_string_only, value}
    end
  end

  defp decode_string(<<str_length::8, value::binary>>, state) do
    {str_bytes, _, state} = decode_fixnum(<<str_length>>, state)

    <<str::size(str_bytes)-bytes, rest::binary>> = value
    <<6, delimiter::8, enc_size::8, rest::binary>> = rest

    case delimiter do
      58 ->
        {enc_size, _, state} = decode_fixnum(<<enc_size>>, state)

        case enc_size do
          1 -> # utf8 or ascii encding <<69, 84>> or <<69, 70>>
            <<_meta::16, rest::binary>> = rest

            {str, rest, state}
          x ->
            <<_encoding_word::size(x)-bytes, 34, encoding_name_size::8, rest::binary>> = rest
            {encoding_name_size, _, state} = decode_fixnum(<<encoding_name_size>>, state)

            <<_enc_name::size(encoding_name_size)-bytes, rest::binary>> = rest

            {str, rest, state}
        end
      59 -> # symbolic link, don't know if I should/can use it
        <<_meta::8, rest::binary>> = rest

        {str, rest, state}
    end
  end

  defp decode_raw_string(<<str_length::8, value::binary>>, state) do
    {str_bytes, _, state} = decode_fixnum(<<str_length>>, state)
    <<value::size(str_bytes)-bytes, rest::binary>> = value

    {value, rest, state}
  end

  defp decode_linked_symbol(<<link::8, rest::binary>>, state) do
    {state[link], rest, state}
  end

  defp decode_symbol(<<symbol_length::8, value::binary>>, state) do
    {symbol_bytes, _, state} = decode_fixnum(<<symbol_length>>, state)

    <<value::size(symbol_bytes)-bytes, rest::binary>> = value
    atom_value = String.to_atom(value)

    links_count= state[:links_count] || 0
    state = Map.put(state, :links_count, links_count)
    state = Map.put(state, links_count, atom_value)
    state = Map.put(state, :links_count, links_count + 1)

    {atom_value, rest, state}
  end

  defp decode_float(<<value::binary>>, state) do
    {float_str, rest, state} = decode_raw_string(value, state)
    {float_value, _} = Float.parse(float_str)

    {float_value, rest, state}
  end

  defp decode_big_decimal(<<58, _::8, _str::size(10)-bytes, value::binary>>, state) do
    {decimal_str, rest, state} = decode_raw_string(value, state)
    [_significant_digits, decimal_value] = String.split(decimal_str, ":")

    {Decimal.new(decimal_value), rest, state}
  end

  defp decode_bignum(<<sign::1-bytes, size_byte::8, value::binary>>, state) do
    {size, _, state} = decode_fixnum(<<size_byte>>, state)
    size = size * 2 * 8

    <<bignum::native-integer-size(size), rest::binary>> = value

    if sign == "+" do
      {bignum, rest, state}
    else
      {bignum * -1, rest, state}
    end
  end

  defp decode_array(value, 0, acc, state) do
    {Enum.reverse(acc), value, state}
  end

  defp decode_array(value, size, acc, state) do
    {element, rest, state} = decode_element(value, state)
    decode_array(rest, size - 1, [element | acc], state)
  end

  defp decode_array(<<0>>, state), do: {[], <<>>, state}

  defp decode_array(<<size::8, value::binary>>, state) do
    {size, _rest, state} = decode_fixnum(<<size>>, state)
    decode_array(value, size, [], state)
  end

  # Ruby Hash
  defp decode_hash(value, 0, acc, state) do
    {Enum.reverse(acc) |> Enum.into(%{}), value, state}
  end

  defp decode_hash(value, size, acc, state) do
    {key, rest, state} = decode_element(value, state)
    {value, rest, state} = decode_element(rest, state)

    decode_hash(rest, size - 1, [{key, value} | acc], state)
  end

  defp decode_hash(<<0>>, state), do: {%{}, <<>>, state}

  defp decode_hash(<<size::8, value::binary>>, state) do
    {size, _rest, state} = decode_fixnum(<<size>>, state)
    decode_hash(value, size, [], state)
  end
end

defmodule ExMarshal.DecodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason() do
      {:ivar_string_only, term} ->
        "only string ivars are supported: #{inspect(term)}"
      {:invalid_encoding, term} ->
        "invalid encoding: #{inspect(term)}"

    end
  end
end
