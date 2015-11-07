defmodule ExMarshal do
  def decode(<<_major::1-bytes, _minor::1-bytes, value::binary>>) do
    case decode_element(value) do
      {value, _rest} -> value
      value -> value
    end
  end

  def decode_element(<<data_type::1-bytes, value::binary>>) do
    case data_type do
      "0" -> nil
      "T" -> true
      "F" -> false
      "i" -> decode_fixnum(value)
      "I" -> decode_ivar(value)
      ":" -> decode_symbol(value)
      "f" -> decode_float(value)
      "u" -> decode_big_decimal(value)
      "l" -> decode_bignum(value)
      "[" -> decode_array(value)
    end
  end

  # Small integers, i.e. -123..122
  def decode_fixnum(<<value::binary>>) do
    <<fixnum_type::8, fixnum_data::binary>> = value

    case fixnum_type do
      0 -> {0, fixnum_data}
      v when v >= 6 and v <= 122 ->
        <<fixnum::signed-little-integer-size(8)>> = <<v>>
        {fixnum - 5, fixnum_data}
      v when v >= 128 and v <= 250 ->
        <<fixnum::signed-little-integer-size(8)>> = <<v>>
        {fixnum + 5, fixnum_data}
      1 ->
        <<fixnum::8, rest::binary>> = fixnum_data

        {fixnum, rest}
      255 ->
        <<value::size(1)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(16)>> = <<value::binary, 255>>

        {fixnum, rest}
      2 ->
        <<value::size(2)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(24)>> = <<value::binary, 0>>

        {fixnum, rest}
      254 ->
        <<value::size(2)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(24)>> = <<value::binary, 255>>

        {fixnum, rest}
      3 ->
        <<value::size(3)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(32)>> = <<value::binary, 0>>

        {fixnum, rest}
      253 ->
        <<value::size(3)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(24)>> = <<value::binary>>

        {fixnum, rest}
      4 ->
        <<value::size(4)-bytes, rest::binary>> = fixnum_data
        <<fixnum::little-integer-size(32)>> = <<value::binary>>

        {fixnum, rest}
      252 ->
        <<value::size(4)-bytes, rest::binary>> = fixnum_data
        <<fixnum::signed-little-integer-size(32)>> = <<value::binary>>

        {fixnum, rest}
    end
  end

  # Raw strings are wrapped into ivars. Currently only string ivars are
  # supported, so decoding an ivar equals to decoding a string.
  #
  # _meta is encoding value, don't know if I need this information here.
  def decode_ivar(<<ivar_type::8, value::binary>>) do
    case ivar_type do
      34 -> decode_string(value)
      _ -> raise ExMarshal.DecodeError, reason: {:ivar_string_only, value}
    end
  end

  def decode_string(<<str_length::8, value::binary>>) do
    {str_bytes, _} = decode_fixnum(<<str_length>>)
    <<value::size(str_bytes)-bytes, meta::size(40), rest::binary>> = value

    {value, rest}
  end

  defp decode_raw_string(<<str_length::8, value::binary>>) do
    {str_bytes, _} = decode_fixnum(<<str_length>>)
    <<value::size(str_bytes)-bytes, rest::binary>> = value

    {value, rest}
  end

  def decode_symbol(<<symbol_length::8, value::binary>>) do
    {symbol_bytes, _} = decode_fixnum(<<symbol_length>>)
    <<value::size(symbol_bytes)-bytes, rest::binary>> = value

    {String.to_atom(value), rest}
  end

  def decode_float(<<value::binary>>) do
    {float_str, rest} = decode_raw_string(value)
    {float_value, _} = Float.parse(float_str)

    {float_value, rest}
  end

  def decode_big_decimal(<<58, _::8, _str::size(10)-bytes, value::binary>>) do
    {decimal_str, rest} = decode_raw_string(value)
    [_significant_digits, decimal_value] = String.split(decimal_str, ":")

    {Decimal.new(decimal_value), rest}
  end

  def decode_bignum(<<sign::1-bytes, size_byte::8, value::binary>>) do
    {size, _} = decode_fixnum(<<size_byte>>)
    size = size * 2 * 8

    <<bignum::native-integer-size(size), rest::binary>> = value

    if sign == "+" do
      {bignum, rest}
    else
      {bignum * -1, rest}
    end
  end

  def decode_array(<<array_size::8, value::binary>>) do
    #array_size = decode_fixnum(<<array_size>>)
    #element = decode_element(value)
  end
end

defmodule ExMarshal.DecodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason() do
      {:ivar_string_only, term} ->
        "only string ivars are supported: #{inspect(term)}"
    end
  end
end
