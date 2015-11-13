defmodule ExMarshalEncoderTest do
  use ExUnit.Case
  doctest ExMarshal

  test "encode nil" do
    encoded_nil = ExMarshal.encode(nil)

    assert <<4, 8, 48>> == encoded_nil
  end

  test "encode true" do
    encoded_true = ExMarshal.encode(true)

    assert <<4, 8, 84>> == encoded_true
  end

  test "encode false" do
    encoded_false = ExMarshal.encode(false)

    assert <<4, 8, 70>> == encoded_false
  end

  test "encode zero" do
    encoded_int = ExMarshal.encode(0)

    assert <<4, 8, 105, 0>> == encoded_int
  end

  test "encode small negative integer as 1 byte" do
    encoded_int = ExMarshal.encode(-120)

    assert <<4, 8, 105, 131>> == encoded_int
  end

  test "encode small positive integer as 1 byte" do
    encoded_int = ExMarshal.encode(120)

    assert <<4, 8, 105, 125>> == encoded_int
  end

  test "encode small positive integer as 1 byte >= 123 and <= 255" do
    encoded_int = ExMarshal.encode(255)

    assert <<4, 8, 105, 1, 255>> == encoded_int
  end

  test "encode small negative integer as 1 byte >= -256 and <= -124" do
    encoded_int = ExMarshal.encode(-256)

    assert <<4, 8, 105, 255, 0>> == encoded_int
  end

  test "encode 2 bytes integer" do
    encoded_int = ExMarshal.encode(256)

    assert <<4, 8, 105, 2, 0, 1>> == encoded_int
  end

  test "encode negative 2-bytes integer" do
    encoded_int = ExMarshal.encode(-300)

    assert <<4, 8, 105, 254, 212, 254>> == encoded_int
  end

  test "encode big 3 bytes integer" do
    encoded_int = ExMarshal.encode(16777215)

    assert <<4, 8, 105, 3, 255, 255, 255>> == encoded_int
  end

  test "encode small 3 bytes integer" do
    encoded_int = ExMarshal.encode(65536)

    assert <<4, 8, 105, 3, 0, 0, 1>> == encoded_int
  end

  test "encode big 3 bytes negative integer" do
    encoded_int = ExMarshal.encode(-16777216)

    assert <<4, 8, 105, 253, 0, 0, 0>> == encoded_int
  end

  test "encode small 4 bytes integer" do
    encoded_int = ExMarshal.encode(16777216)

    assert <<4, 8, 105, 4, 0, 0, 0, 1>> == encoded_int
  end

  test "encode big 4 bytes integer" do
    encoded_int = ExMarshal.encode(1073741823)

    assert <<4, 8, 105, 4, 255, 255, 255, 63>> == encoded_int
  end

  test "encode positive bignum" do
    encoded_bignum = ExMarshal.encode(1073741824)

    assert <<4, 8, 108, 43, 7, 0, 0, 0, 64>> == encoded_bignum
  end

  test "encode negative bignum" do
    encoded_bignum = ExMarshal.encode(-10737418243)

    assert <<4, 8, 108, 45, 8, 3, 0, 0, 128, 2, 0>> == encoded_bignum
  end

  test "encode string" do
    encoded_string = ExMarshal.encode("é")

    assert <<4, 8, 73, 34, 7, 195, 169, 6, 58, 6, 69, 84>> == encoded_string
  end

  test "encode float" do
    encoded_float = ExMarshal.encode(1.012345)

    assert <<4, 8, 102, 13, 49, 46, 48, 49, 50, 51, 52, 53>> == encoded_float
  end

  test "encode atom" do
    encoded_atom = ExMarshal.encode(:busy)

    assert <<4, 8, 58, 9, 98, 117, 115, 121>> == encoded_atom
  end

  test "encode list" do
    encoded_list = ExMarshal.encode([1, 2, 3])

    assert <<4, 8, 91, 8, 105, 6, 105, 7, 105, 8>> == encoded_list
  end

  test "encode list with links" do
    encoded_list = ExMarshal.encode([:busy, :busy, :foo, :bar, :busy])

    assert <<4, 8, 91, 10, 58, 9, 98, 117, 115, 121, 59, 0, 58, 8, 102, 111, 111, 58, 8, 98, 97, 114, 59, 0>> == encoded_list
  end

  test "encode complex list" do
    encoded_list = ExMarshal.encode([:one, "two", 3, [:four, :one], -265, [[]], "ten"])

    assert <<4, 8, 91, 12, 58, 8, 111, 110, 101, 73, 34, 8, 116, 119, 111, 6, 58, 6, 69, 84, 105, 8, 91, 7, 58, 9, 102, 111, 117, 114, 59, 0, 105, 254, 247, 254, 91, 6, 91, 0, 73, 34, 8, 116, 101, 110, 6, 59, 6, 84>> == encoded_list
  end

  test "encode list of strings" do
    encoded_list = ExMarshal.encode(["one", "two", "123", "hello world"])

    assert <<4, 8, 91, 9, 73, 34, 8, 111, 110, 101, 6, 58, 6, 69, 84, 73, 34, 8, 116, 119, 111, 6, 59, 0, 84, 73, 34, 8, 49, 50, 51, 6, 59, 0, 84, 73, 34, 16, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 6, 59, 0, 84>> == encoded_list
  end

  test "encode simple map" do
    encoded_map = ExMarshal.encode(%{one: "one", two: "two"})

    assert <<4, 8, 123, 7, 58, 8, 111, 110, 101, 73, 34, 8, 111, 110, 101, 6, 58, 6, 69, 84, 58, 8, 116, 119, 111, 73, 34, 8, 116, 119, 111, 6, 59, 6, 84>> == encoded_map
  end
end
