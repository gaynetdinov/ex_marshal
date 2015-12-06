defmodule ExMarshalDecoderTest do
  use ExUnit.Case
  doctest ExMarshal

  test "decode nil" do
    decoded_nil = ExMarshal.decode(<<4, 8, 48>>)

    assert nil == decoded_nil
  end

  test "decode false" do
    decoded_false = ExMarshal.decode(<<4, 8, 70>>)

    assert false == decoded_false
  end

  test "decode true" do
    decoded_true = ExMarshal.decode(<<4, 8, 84>>)

    assert true = decoded_true
  end

  test "decode simple string" do
    decoded_str = ExMarshal.decode(
      <<4, 8, 73, 34, 16, 104, 101, 108, 108,
      111, 32, 119, 111, 114, 108, 100, 6, 58, 6, 69, 84>>
    )
    assert "hello world" == decoded_str
  end

  test "decode utf8 string" do
    decoded_str = ExMarshal.decode(
      <<4, 8, 73, 34, 17, 208, 191, 209, 128, 208, 184,
      208, 178, 208, 181, 209, 130, 6, 58, 6, 69, 84>>
    )

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
    decoded_symbol = ExMarshal.decode(
      <<4, 8, 58, 16, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100>>
    )

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
    decoded_int = ExMarshal.decode(<<4, 8, 105, 131>>)

    assert -120 == decoded_int
  end

  test "decode 1 byte integer" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 1, 254>>)

    assert 254 == decoded_int
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
    decoded_big_decimal = ExMarshal.decode(
      <<4, 8, 117, 58, 15, 66, 105, 103, 68, 101, 99, 105, 109,
      97, 108, 15, 49, 56, 58, 48, 46, 49, 50, 51, 69, 49>>
    )

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

  test "decode empty array" do
    decoded_array = ExMarshal.decode(<<4, 8, 91, 0>>)

    assert [] == decoded_array
  end

  test "decode simple array of integers" do
    decoded_array = ExMarshal.decode(<<4, 8, 91, 8, 105, 6, 105, 7, 105, 8>>)

    assert [1, 2, 3] == decoded_array
  end

  test "decode simple array of strings" do
    decoded_array = ExMarshal.decode(
      <<4, 8, 91, 8, 73, 34, 6, 97, 6, 58, 6, 69, 84, 73,
      34, 6, 98, 6, 59, 0, 84, 73, 34, 6, 99, 6, 59, 0, 84>>
    )

    assert ["a", "b", "c"] == decoded_array
  end

  test "decode array of string with different encodings" do
    decoded_array = ExMarshal.decode(
      <<4, 8, 91, 8, 73, 34, 6, 97, 6, 58, 6, 69, 84, 73, 34, 6, 98,
      6, 59, 0, 70, 73, 34, 6, 99, 6, 58, 13, 101, 110, 99, 111,
      100, 105, 110, 103, 34, 14, 83, 104, 105, 102, 116, 95, 74, 73, 83>>
    )

    assert ["a", "b", "c"] == decoded_array
  end

  test "decode nested array" do
    decoded_array = ExMarshal.decode(<<4, 8, 91, 6, 91, 6, 91, 6, 91, 6, 105, 6>>)

    assert [[[[1]]]] == decoded_array
  end

  test "decode arrays of symbols with links" do
    decoded_array = ExMarshal.decode(
      <<4, 8, 91, 11, 58, 8, 111, 110, 101, 59, 0, 58, 8, 116,
      119, 111, 59, 6, 58, 10, 116, 104, 114, 101, 101, 59, 0>>
    )

    assert [:one, :one, :two, :two, :three, :one] == decoded_array
  end

  test "decode complex array" do
    decoded_array = ExMarshal.decode(<<4, 8, 91, 12, 58, 8, 111, 110, 101, 73, 34, 8,
      116, 119, 111, 6, 58, 6, 69, 84, 105, 8, 91, 7, 58, 9, 102, 111, 117, 114, 59,
      0, 105, 254, 247, 254, 91, 6, 91, 0, 73, 34, 8, 116, 101, 110, 6, 58, 13, 101,
      110, 99, 111, 100, 105, 110, 103, 34, 14, 83, 104, 105, 102, 116, 95, 74, 73, 83>>)

    assert [:one, "two", 3, [:four, :one], -265, [[]], "ten"] == decoded_array
  end

  test "decode empty hash" do
    decoded_hash = ExMarshal.decode(<<4, 8, 123, 0>>)

    assert %{} == decoded_hash
  end

  test "decode simple hash" do
    decoded_hash = ExMarshal.decode(
      <<4, 8, 123, 6, 58, 8, 111, 110, 101, 73, 34, 8, 111, 110, 101, 6, 58, 6, 69, 84>>
    )

    assert %{one: "one"} == decoded_hash
  end

  test "decode complex hash" do
    decoded_hash = ExMarshal.decode(<<4, 8, 123, 9, 58, 8, 111, 110, 101,
      73, 34, 8, 116, 119, 111, 6, 58, 6, 69, 84, 73, 34, 10, 116, 104,
      114, 101, 101, 6, 59, 6, 84, 105, 9, 73, 34, 10, 102, 195, 188, 110,
      102, 6, 59, 6, 84, 91, 9, 59, 0, 105, 7, 73, 34, 10, 116, 104, 114,
      101, 101, 6, 59, 6, 84, 123, 6, 73, 34, 0, 6, 59, 6, 84, 91, 0, 73,
      34, 15, 209, 136, 208, 181, 209, 129, 209, 130, 209, 140, 6, 59, 6, 84, 105, 11>>)

    expected_hash = %{
      :one => "two",
      "three" => 4,
      "fünf" => [:one, 2, "three", %{"" => []}],
      "шесть" => 6
    }

    assert expected_hash == decoded_hash
  end

  test "decode referenced string" do
    ruby_encoded = File.read!("./test/fixtures/ref_1.bin")

    decoded_ref = ExMarshal.decode(ruby_encoded)

    assert ["hello", "hello", "hi", "hi", "ola", "ola"] == decoded_ref
  end

  test "decode referenced array" do
    ruby_encoded = File.read!("./test/fixtures/ref_2.bin")

    decoded_ref = ExMarshal.decode(ruby_encoded)

    assert [[1, :two, "three", []], [1, :two, "three", []]] == decoded_ref
  end

  test "decode referenced hash" do
    ruby_encoded = File.read!("./test/fixtures/ref_2.bin")

    decoded_map = ExMarshal.decode(ruby_encoded)

    expected_map = %{
      one: %{one: 1, two: "two", three: :three, four: [[]]},
      two: %{one: 1, two: "two", three: :three, four: [[]]}
    }
    assert expected_map, decoded_map
  end

  test "raises exception for non-supported symbol" do
    ruby_encoded = File.read!("./test/fixtures/regexp.bin")

    assert_raise ExMarshal.DecodeError, fn ->
      ExMarshal.decode(ruby_encoded)
    end
  end
end
