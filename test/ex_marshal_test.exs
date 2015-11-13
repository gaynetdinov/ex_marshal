defmodule ExMarshalTest do
  use ExUnit.Case
  doctest ExMarshal

  test "encode and decode complex map" do
    map = %{
      :one => "two",
      "three" => 4,
      "fünf" => [:one, 2, "three", %{"" => []}],
      "шесть" => 6
    }

    assert map == ExMarshal.encode(map) |> ExMarshal.decode
  end

  test "encode and decode complex list" do
    list = [:one, "two", 3, [:four, :one], -265, [[]], "ten"]

    assert list == ExMarshal.encode(list) |> ExMarshal.decode
  end
end
