defmodule ExMarshal.DecodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason() do
      {:ivar_string_only, term} ->
        "only string ivars are supported: #{inspect(term)}"
    end
  end
end

defmodule ExMarshal do
  def decode(<<_major::1-bytes, _minor::1-bytes, value::binary>>) do
    <<data_type::1-bytes, value::binary>> = value
    case data_type do
      "0" -> nil
      "T" -> true
      "F" -> false
      "i" -> decode_fixnum(value)
      "I" -> decode_ivar(value)
      ":" -> decode_symbol(value)
      "f" -> decode_float(value)
      "u" -> decode_big_decimal(value)
    end
  end

  def decode_fixnum(<<value::8>>) when value == 0, do: 0

  # Small integers, i.e. -123..122
  def decode_fixnum(<<value::8>>) do
    <<fixnum::signed-little-integer-size(8)>> = <<value>>

    if fixnum < 0 do
      fixnum + 5
    else
      fixnum - 5
    end
  end

  def decode_fixnum(<<1, value::binary>>), do: value

  def decode_fixnum(<<255, value::binary>>) do
    <<fixnum::signed-little-integer-size(16)>> = <<value::binary, 255>>

    fixnum
  end

  def decode_fixnum(<<2, value::binary>>) do
    <<fixnum::little-integer-size(24)>> = <<value::binary, 0>>

    fixnum
  end

  def decode_fixnum(<<254, value::binary>>) do
    <<fixnum::signed-little-integer-size(24)>> = <<value::binary, 255>>

    fixnum
  end

  def decode_fixnum(<<3, value::binary>>) do
    <<fixnum::little-integer-size(32)>> = <<value::binary, 0>>

    fixnum
  end

  def decode_fixnum(<<253, value::binary>>) do
    <<fixnum::signed-little-integer-size(24)>> = <<value::binary>>

    fixnum
  end

  def decode_fixnum(<<4, value::binary>>) do
    <<fixnum::little-integer-size(32)>> = <<value::binary>>

    fixnum
  end

  def decode_fixnum(<<252, value::binary>>) do
    <<fixnum::signed-little-integer-size(32)>> = <<value::binary>>

    fixnum
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
    str_bytes = decode_fixnum(<<str_length>>)
    <<value :: size(str_bytes)-bytes, _meta :: binary>> = value

    value
  end

  def decode_symbol(<<_symbol_length::8, value::binary>>) do
    String.to_atom(value)
  end

  def decode_float(<<value::binary>>) do
    float_str = decode_string(value)
    {float_value, _} = Float.parse(float_str)

    float_value
  end

  def decode_big_decimal(<<58, _::8, _str::size(10)-bytes, value::binary>>) do
    decimal_str = decode_string(value)
    [_significant_digits, decimal_value] = String.split(decimal_str, ":")

    Decimal.new(decimal_value)
  end
end
