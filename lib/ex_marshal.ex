defmodule ExMarshal do
  def decode(<<_major::1-bytes, _minor::1-bytes, value :: binary>>) do
    <<data_type::1-bytes, value::binary>> = value
    case data_type do
      "0" -> nil
      "T" -> true
      "F" -> false
      "i" -> decode_fixnum(value)
      "I" -> decode_ivar(value)
    end
  end

  # Small integers, i.e. -123..122
  def decode_fixnum(<<value::size(8)>>) do
    case value do
      v when v >= 128 and v <= 250 -> v - 256 + 5
      v when v >= 6 and v <= 122 -> v - 5
    end
  end

  # Large integers
  def decode_fixnum(<<bytes :: size(8), value :: binary>>) when bytes <= 30 do
    size = bytes * 8
    <<number :: little-integer-size(size)>> = value

    number
  end

  # Large negative integers
  def decode_fixnum(<<bytes :: integer-signed-size(8), value :: binary>>) do
    size = bytes * -8
    <<number :: signed-little-integer-size(size)>> = value

    number
  end

  # Raw strings are wrapped into ivars. Currently only string ivars are
  # supported, so decoding an ivar equals to decoding a string.
  #
  # _meta is encoding value, don't know if I need this information here.
  def decode_ivar(<<34, str_bytes :: size(8), value :: binary>>) do
    str_bytes = decode_fixnum(<<str_bytes>>)
    <<value :: size(str_bytes)-bytes, _meta :: binary>> = value

    value
  end
end
