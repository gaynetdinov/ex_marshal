defmodule ExMarshal.Encoder do
  def encode(value) do
    {value_binary, _state} = encode_element(value, %{})

    <<4, 8, value_binary::binary>>
  end

  defp encode_element(value, state) do
    case value do
      nil -> {<<48>>, state}
      true -> {<<84>>, state}
      false -> {<<70>>, state}
      int when is_integer(int) ->
        case int do
          v when v < 1073741824 and v > -1073741825 -> encode_fixnum(v, state)
          v when v >= 1073741824 or v <= -1073741825 -> encode_bignum(v, state)
        end
      str when is_bitstring(str) -> encode_string(str, state)
      atom when is_atom(atom) -> encode_atom(atom, state)
      list when is_list(list) -> encode_list(list, state)
      float when is_float(float) -> encode_float(float, state)
      %Decimal{} -> encode_decimal(value, state)
      map when is_map(map) -> encode_map(map, state)
      _ -> raise ExMarshal.EncodeError, reason: {:not_supported, value}
    end
  end

  def encode_decimal(value, state) do
    value_str = "18:" <> Decimal.to_string(value)
    {value_encoded, state} = encode_raw_string(value_str, state)
    decimal_format = <<117, 58, 15, 66, 105, 103, 68, 101, 99, 105, 109, 97, 108>>

    encoded_value = decimal_format <> <<value_encoded::binary>>

    {encoded_value, state}
  end

  defp encode_map(%{__struct__: _} = struct, _) do
    raise ExMarshal.EncodeError, reason: {:not_supported, struct}
  end

  defp encode_map(value, state) do
    value = Enum.into(value, [])
    {size, state} = encode_fixnum(Enum.count(value), state)
    <<105, size>> = size

    {value_encoded, state} = encode_map(value, <<>>, state)
    {<<123, size, value_encoded::binary>>, state}
  end

  defp encode_map([], acc, state), do: {acc, state}

  defp encode_map(map, acc, state) do
    [{key,value} | tail] = map
    {encoded_key, state} = encode_element(key, state)
    {encoded_value, state} = encode_element(value, state)

    encode_map(tail, <<acc::binary, encoded_key::binary, encoded_value::binary>>, state)
  end

  defp encode_list(value, state) do
    {size, state} = encode_fixnum(Enum.count(value), state)
    <<105, size>> = size

    {list_binary, state} = encode_list(value, <<>>, state)
    {<<91, size, list_binary::binary>>, state}
  end

  defp encode_list([], acc, state), do: {acc, state}

  defp encode_list(value, acc, state) do
    [head | tail] = value
    {element, state} = encode_element(head, state)

    encode_list(tail, <<acc::binary, element::binary>>, state)
  end

  defp encode_atom(value, state) do
    value_str = to_string(value)
    {encoded_value, state} = encode_raw_string(value_str, state)

    links_count = links_count(state)

    if !Map.has_key?(state, encoded_value) do
      state = Map.put(state, encoded_value, links_count)
      state = Map.put(state, :links_count, links_count)

      {<<58, encoded_value::binary>>, state}
    else
      link = state[encoded_value]

      {<<59, link>>, state}
    end
  end

  defp encode_float(value, state) do
    value_str = :erlang.float_to_binary(value, [:compact, decimals: 10])

    {encoded_value, state} = encode_raw_string(value_str, state)

    {<<102, encoded_value::binary>>, state}
  end

  defp encode_string(value, state) do
    byte_size = byte_size(value)
    {encoded_size, state} = encode_fixnum(byte_size, state)
    <<105, encoded_size>> = encoded_size

    links_count = links_count(state)

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

  defp encode_bignum(value, state) do
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

  defp encode_fixnum(value, state) do
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

  defp encode_raw_string(value, state) do
    byte_size = byte_size(value)
    {encoded_size, state} = encode_fixnum(byte_size, state)
    <<105, encoded_size>> = encoded_size

    {<<encoded_size, value::size(byte_size)-bytes>>, state}
  end

  defp count_bits(value) do
    bits = trunc(:math.log(abs(value)) / :math.log(2)) + 1
    case rem(bits, 16) do
      0 -> bits
      _ -> bits - rem(bits, 16) + 16
    end
  end

  defp links_count(state) do
    if state[:links_count] do
      {count, _state} = encode_fixnum(state[:links_count] + 1, state)
      <<105, count>> = count

      count
    else
      0
    end
  end
end

defmodule ExMarshal.EncodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason() do
      {:not_supported, term} ->
        "the following type is not supported: #{inspect(term)}"
    end
  end
end
