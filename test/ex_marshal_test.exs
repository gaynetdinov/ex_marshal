defmodule ExMarshalTest do
  use ExUnit.Case
  doctest ExMarshal

  test "encode and decode complex map" do
    map = %{
      :one => "two",
      "three" => 4,
      "fünf" => [nil, true, false, :one, 2, "three", %{"" => []}],
      "шесть" => 6,
    }

    assert map == ExMarshal.encode(map) |> ExMarshal.decode
  end

  test "encode and decode complex list" do
    list = [:one, "two", 3, [:four, :one], -265, [[]], "ten"]

    assert list == ExMarshal.encode(list) |> ExMarshal.decode
  end

  test "encode and decode Decimal" do
    decimal = Decimal.new("1.01234567089")

    assert decimal == ExMarshal.encode(decimal) |> ExMarshal.decode
  end

  # Ruby Marshal encodes BigDecimal as `18:0.123E1`, but ExMarshal encodes
  # Decimal as `18:1.23`. `BigDecimal._load` method which is used to
  # decode marshalled data supports both formats, that's why binary
  # representations of ruby version and ExMarshal version do not match,
  # but decoded value is the same.
  test "decode and encode BigDecimal" do
    original_value = Decimal.new("1.01234567089")
    ruby_encoded = File.read!("./test/fixtures/big_decimal.bin")
    ex_marshal_encoded = ExMarshal.encode(original_value)

    assert ExMarshal.decode(ruby_encoded) == ExMarshal.decode(ex_marshal_encoded)
  end

  test "encode and decode a very long string" do
    string = "http://usertesting.dev/admins/auth/google_oauth2/callback?state=eec87db6b1eaf789d869c6ad7def175d6d50240060b95f24&code=4/ItZbxW-FxI0TlRQelK0N-cWcUdPl1NzQ IRTrI6H3AI0"

    assert string == ExMarshal.encode(string) |> ExMarshal.decode
  end

  test "repetitive symbols" do
    original_value = %{first: %{key: [:success]}, second: %{success: "yes"}}
    ruby_encoded = File.read!("./test/fixtures/repetitive_symbols.bin")
    ex_marshal_encoded = ExMarshal.encode(original_value)

    assert ExMarshal.decode(ruby_encoded) == ExMarshal.decode(ex_marshal_encoded)
  end
end
