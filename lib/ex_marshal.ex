defmodule ExMarshal do
  def decode(<<_major::1-bytes, _minor::1-bytes, value::binary>>) do
    case decode_element(value, %{}) do
      {value, _rest, _state} -> value
      # _ -> raise
    end
  end

  def decode_element(<<data_type::1-bytes, value::binary>>, state) do
    case data_type do
      "0" -> nil
      "T" -> true
      "F" -> false
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

  def encode(value) do
    {value_binary, _state} = encode_element(value, %{})

    <<4, 8, value_binary::binary>>
  end

  def encode_element(value, state) do
    case value do
      nil -> {<<48>>, state}
      true -> {<<84>>, state}
      false -> {<<70>>, state}
      int when is_integer(int) ->
        case int do
          v when v < 1073741824 and v > -1073741825 -> encode_fixnum(v, state)
          v when v >= 1073741824 or v <= -1073741825 -> encode_bignum(v, state)
          #_ -> raise encode exception
        end
        str when is_bitstring(str) -> encode_string(str, state)
        atom when is_atom(atom) -> encode_atom(atom, state)
        list when is_list(list) -> encode_list(list, state)
        float when is_float(float) -> encode_float(float, state)
        map when is_map(map) -> encode_map(Enum.into(map, []), state)
      #_ -> raise unsupported format
    end
  end

  def encode_map(value, state) do
    IO.inspect(value)
    {size, state} = encode_fixnum(Enum.count(value), state)
    <<105, size>> = size

    {value_encoded, state} = encode_map(value, <<>>, state)
    {<<123, size, value_encoded::binary>>, state}
  end

  def encode_map([], acc, state), do: {acc, state}

  def encode_map(map, acc, state) do
    [{key,value} | tail] = map
    {encoded_key, state} = encode_element(key, state)
    {encoded_value, state} = encode_element(value, state)
    encode_map(tail, <<acc::binary, encoded_key::binary, encoded_value::binary>>, state)
  end

  def encode_list(value, state) do
    {size, state} = encode_fixnum(Enum.count(value), state)
    <<105, size>> = size

    {list_binary, state} = encode_list(value, <<>>, state)
    {<<91, size, list_binary::binary>>, state}
  end

  def encode_list([], acc, state), do: {acc, state}

  def encode_list(value, acc, state) do
    [head | tail] = value
    {element, state} = encode_element(head, state)

    encode_list(tail, <<acc::binary, element::binary>>, state)
  end

  def encode_atom(value, state) do
    value_str = to_string(value)
    {encoded_value, state} = encode_raw_string(value_str, state)

    links_count = if state[:links_count] do
      {count, state} = encode_fixnum(state[:links_count] + 1, state)
      <<105, count>> = count
      count
    else
      0
    end

    if !Map.has_key?(state, encoded_value) do
      state = Map.put(state, encoded_value, links_count)
      state = Map.put(state, :links_count, links_count)

      {<<58, encoded_value::binary>>, state}
    else
      link = state[encoded_value]

      {<<59, link>>, state}
    end
  end

  def encode_float(value, state) do
    value_str = Float.to_string(value, [decimals: 10, compact: true])

    {encoded_value, state} = encode_raw_string(value_str, state)

    {<<102, encoded_value::binary>>, state}
  end

  def encode_string(value, state) do
    byte_size = byte_size(value)
    {encoded_size, state} = encode_fixnum(byte_size, state)
    <<105, encoded_size>> = encoded_size

    links_count = if state[:links_count] do
      {count, state} = encode_fixnum(state[:links_count] + 1, state)
      <<105, count>> = count
      count
    else
      0
    end

    utf8_encoding = <<58, 6, 69>>

    if !Map.has_key?(state, utf8_encoding) do
      state = Map.put(state, utf8_encoding, links_count)
      state = Map.put(state, :links_count, links_count)

      {<<73, 34, encoded_size, value::size(byte_size)-bytes, 6, utf8_encoding::binary, 84>>, state}
    else
      link = state[utf8_encoding]

      {<<73, 34, encoded_size, value::size(byte_size)-bytes, 6, 59, link, 84>>, state}
    end
  end

  def encode_raw_string(value, state) do
    byte_size = byte_size(value)
    {encoded_size, state} = encode_fixnum(byte_size, state)
    <<105, encoded_size>> = encoded_size

    {<<encoded_size, value::size(byte_size)-bytes>>, state}
  end

  def encode_bignum(value, state) do
    sign = if value > 0 do
      <<43>>
    else
      <<45>>
    end

    bit_size = count_bits(value)
    {encoded_byte_size, state} = encode_fixnum(trunc(bit_size / 16), state)
    <<105, encoded_byte_size>> = encoded_byte_size

    {<<108, sign::binary, encoded_byte_size, abs(value)::native-integer-size(bit_size)>>, state}
  end

  def count_bits(value) do
    bits = trunc(:math.log(abs(value)) / :math.log(2)) + 1
    case rem(bits, 16) do
      0 -> bits
      _ -> bits - rem(bits, 16) + 16
    end
  end

  def encode_fixnum(value, state) do
    case value do
      0 -> {<<105, 0>>, state}
      small_int when small_int <= -1 and small_int >= -123 ->
        value = small_int - 5
        {<<105, value::signed-little-integer-size(8)>>, state}
      small_int when small_int >= 1 and small_int <= 122 ->
        value = small_int + 5
        {<<105, value::little-integer-size(8)>>, state}
      small_int when small_int >= 123 and small_int <= 255 ->
        {<<105, 1, small_int>>, state}
      small_int when small_int <= -124 and small_int >= -256 ->
        {<<105, 255, small_int::signed-little-integer-size(8)>>, state}
      int when int >= 256 and int <= 65535 ->
        value_binary = <<int::little-integer-size(24)>>
        <<value_truncated::2-bytes, _rest>> = value_binary
        {<<105, 2, value_truncated::binary>>, state}
      int when int <= -257 and int >= -65536 ->
        value_binary = <<int::signed-little-integer-size(24)>>
        <<value_truncated::2-bytes, _rest>> = value_binary
        {<<105, 254, value_truncated::binary>>, state}
      bigint when bigint >= 65536 and bigint < 16777216 ->
        {<<105, 3, bigint::little-integer-size(24)>>, state}
      bigint when bigint <= -65537 and bigint >= -16777216 ->
        {<<105, 253, bigint::signed-little-integer-size(24)>>, state}
      bigint when bigint >= 16777216 and bigint < 1073741824 ->
        {<<105, 4, bigint::little-integer-size(32)>>, state}
      bigint when bigint <= -16777217 and bigint >= -1073741824 ->
        {<<105, 252, bigint::little-integer-size(32)>>, state}
    end
  end

  # Small integers, i.e. -123..122
  def decode_fixnum(<<value::binary>>, state) do
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
  def decode_ivar(<<ivar_type::8, value::binary>>, state) do
    case ivar_type do
      34 -> decode_string(value, state)
      _ -> raise ExMarshal.DecodeError, reason: {:ivar_string_only, value}
    end
  end

  def decode_string(<<str_length::8, value::binary>>, state) do
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

  def decode_linked_symbol(<<link::8, rest::binary>>, state) do
    {state[link], rest, state}
  end

  def decode_symbol(<<symbol_length::8, value::binary>>, state) do
    {symbol_bytes, _, state} = decode_fixnum(<<symbol_length>>, state)

    <<value::size(symbol_bytes)-bytes, rest::binary>> = value
    atom_value = String.to_atom(value)

    links_count= state[:links_count] || 0
    state = Map.put(state, :links_count, links_count)
    state = Map.put(state, links_count, atom_value)
    state = Map.put(state, :links_count, links_count + 1)

    {atom_value, rest, state}
  end

  def decode_float(<<value::binary>>, state) do
    {float_str, rest, state} = decode_raw_string(value, state)
    {float_value, _} = Float.parse(float_str)

    {float_value, rest, state}
  end

  def decode_big_decimal(<<58, _::8, _str::size(10)-bytes, value::binary>>, state) do
    {decimal_str, rest, state} = decode_raw_string(value, state)
    [_significant_digits, decimal_value] = String.split(decimal_str, ":")

    {Decimal.new(decimal_value), rest, state}
  end

  def decode_bignum(<<sign::1-bytes, size_byte::8, value::binary>>, state) do
    {size, _, state} = decode_fixnum(<<size_byte>>, state)
    size = size * 2 * 8

    <<bignum::native-integer-size(size), rest::binary>> = value

    if sign == "+" do
      {bignum, rest, state}
    else
      {bignum * -1, rest, state}
    end
  end

  def decode_array(value, 0, acc, state) do
    {Enum.reverse(acc), value, state}
  end

  def decode_array(value, size, acc, state) do
    {element, rest, state} = decode_element(value, state)
    decode_array(rest, size - 1, [element | acc], state)
  end

  def decode_array(<<0>>, state), do: {[], <<>>, state}

  def decode_array(<<size::8, value::binary>>, state) do
    {size, _rest, state} = decode_fixnum(<<size>>, state)
    decode_array(value, size, [], state)
  end

  # Ruby Hash
  def decode_hash(value, 0, acc, state) do
    {Enum.reverse(acc) |> Enum.into(%{}), value, state}
  end

  def decode_hash(value, size, acc, state) do
    {key, rest, state} = decode_element(value, state)
    {value, rest, state} = decode_element(rest, state)

    decode_hash(rest, size - 1, [{key, value} | acc], state)
  end

  def decode_hash(<<0>>, state), do: {%{}, <<>>, state}

  def decode_hash(<<size::8, value::binary>>, state) do
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
