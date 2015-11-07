defmodule ExMarshalTest do
  use ExUnit.Case
  doctest ExMarshal

  test "decode simple string" do
    decoded_str = ExMarshal.decode(<<4, 8, 73, 34, 16, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 6, 58, 6, 69, 84>>)
    assert "hello world" == decoded_str
  end

  test "decode utf8 string" do
    decoded_str = ExMarshal.decode(<<4, 8, 73, 34, 17, 208, 191, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130, 6, 58, 6, 69, 84>>)

    assert "привет" == decoded_str
  end

  test "decode utf8 string with special character" do
    decoded_str = ExMarshal.decode(<<4, 8, 73, 34, 9, 111, 108, 195, 160, 6, 58, 6, 69, 84>>)

    assert "olà" == decoded_str
  end

  test "decode simple symbol" do
    decoded_symbol = ExMarshal.decode(<<4, 8, 58, 11, 115, 121, 109, 98, 111, 108>>)

    assert :symbol == decoded_symbol
  end

  test "decode symbol with spaces" do
    decoded_symbol = ExMarshal.decode(<<4, 8, 58, 16, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100>>)

    assert :"hello world" == decoded_symbol
  end

  test "decode zero" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 0>>)

    assert 0 == decoded_int
  end

  test "decode small integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 105>>)

    assert 100 == decoded_int
  end

  test "decode small negative integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 151>>)

    assert -100 == decoded_int
  end

  test "decode 2 bytes integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 2, 0, 1>>)

    assert 256 == decoded_int
  end

  test "decode 2 bytes negative integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 255, 0>>)

    assert -256 == decoded_int
  end

  test "decode 3 bytes integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 3, 0, 0, 1>>)

    assert 65536 == decoded_int
  end

  test "decode 3 bytes negative integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 254, 0, 0>>)

    assert -65536 == decoded_int
  end

  test "decode 4 bytes integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 4, 255, 255, 255, 63>>)

    assert 1073741823 == decoded_int
  end

  test "decode 4 bytes negative integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 252, 0, 0, 0, 192>>)

    assert -1073741824 == decoded_int
  end

  test "decode float" do
    decoded_float = ExMarshal.decode(<<4, 8, 102, 9, 49, 46, 50, 51>>)

    assert 1.23 == decoded_float
  end

  test "decode big decimal" do
    decoded_big_decimal = ExMarshal.decode(<<4, 8, 117, 58, 15, 66, 105, 103, 68, 101, 99, 105, 109, 97, 108, 15, 49, 56, 58, 48, 46, 49, 50, 51, 69, 49>>)

    assert Decimal.new("1.23") == decoded_big_decimal
  end

  test "decode positive bignum" do
    decoded_bignum = ExMarshal.decode(<<4, 8, 108, 43, 7, 0, 0, 0, 64>>)

    assert 1073741824 == decoded_bignum
  end

  test "decode negative bignum" do
    decoded_bignum = ExMarshal.decode(<<4, 8, 108, 45, 7, 1, 0, 0, 64>>)

    assert -1073741825 == decoded_bignum
  end
end
