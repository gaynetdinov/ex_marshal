defmodule ExMarshalEncodeTest do
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
end
