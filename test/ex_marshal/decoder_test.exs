defmodule ExMarshalDecoderTest do
  use ExUnit.Case
  doctest ExMarshal
  alias ExMarshal.Errors.DecodeError

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

  test "decode small integer 2" do
    decoded_int = ExMarshal.decode(<<4, 8, 105, 123>>)

    assert 118 == decoded_int
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

  test "decode hash with empty strings" do
    ruby_encoded = File.read!("./test/fixtures/hash_with_empty_strings.bin")

    decoded_hash = ExMarshal.decode(ruby_encoded)

    assert decoded_hash == %{"foo" => "", "" => ""}
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

  test "decode a rails session" do
    binary = <<4, 8, 123, 21, 73, 34, 15, 115, 101, 115, 115, 105, 111, 110, 95, 105, 100, 6,
      58, 6, 69, 84, 73, 34, 69, 97, 55, 100, 51, 53, 56, 54, 52, 56, 102, 49, 54,
      97, 50, 101, 100, 53, 100, 54, 54, 100, 100, 50, 97, 98, 97, 55, 55, 54, 97,
      57, 57, 55, 51, 48, 52, 50, 97, 54, 102, 52, 100, 53, 49, 49, 97, 48, 101, 57,
      50, 100, 54, 98, 102, 56, 100, 48, 99, 101, 52, 55, 53, 50, 54, 6, 59, 0, 70,
      73, 34, 16, 95, 99, 115, 114, 102, 95, 116, 111, 107, 101, 110, 6, 59, 0, 70,
      73, 34, 49, 101, 86, 53, 98, 114, 74, 76, 115, 114, 80, 111, 103, 107, 76, 47,
      66, 108, 65, 74, 67, 109, 107, 76, 109, 51, 74, 49, 99, 101, 74, 102, 43, 81,
      71, 54, 97, 47, 98, 85, 66, 99, 81, 107, 61, 6, 59, 0, 70, 73, 34, 27, 97, 99,
      99, 111, 117, 110, 116, 95, 99, 101, 110, 116, 101, 114, 95, 117, 115, 101,
      114, 95, 105, 100, 6, 59, 0, 70, 105, 6, 73, 34, 36, 97, 99, 99, 111, 117,
      110, 116, 95, 99, 101, 110, 116, 101, 114, 95, 118, 101, 114, 105, 102, 105,
      101, 100, 95, 117, 115, 101, 114, 95, 105, 100, 6, 59, 0, 70, 105, 6, 73, 34,
      35, 97, 99, 99, 111, 117, 110, 116, 95, 99, 101, 110, 116, 101, 114, 95, 111,
      114, 103, 97, 110, 105, 122, 97, 116, 105, 111, 110, 95, 105, 100, 6, 59, 0,
      70, 105, 6, 73, 34, 25, 115, 104, 111, 119, 95, 98, 114, 111, 119, 115, 101,
      114, 95, 119, 97, 114, 110, 105, 110, 103, 6, 59, 0, 70, 70, 73, 34, 23, 97,
      112, 112, 95, 118, 101, 114, 115, 105, 111, 110, 95, 115, 116, 114, 105, 110,
      103, 6, 59, 0, 70, 73, 34, 8, 48, 46, 48, 6, 59, 0, 70, 73, 34, 21, 115, 101,
      115, 115, 105, 111, 110, 95, 105, 110, 95, 114, 101, 100, 105, 115, 6, 59, 0,
      70, 84, 73, 34, 14, 103, 117, 101, 115, 116, 95, 105, 100, 115, 6, 59, 0, 70,
      91, 0, 73, 34, 9, 99, 115, 114, 102, 6, 59, 0, 70, 64, 9, 73, 34, 13, 116,
      114, 97, 99, 107, 105, 110, 103, 6, 59, 0, 70, 123, 7, 73, 34, 20, 72, 84, 84,
      80, 95, 85, 83, 69, 82, 95, 65, 71, 69, 78, 84, 6, 59, 0, 84, 73, 34, 45, 100,
      99, 101, 53, 98, 101, 50, 56, 53, 98, 52, 102, 99, 52, 53, 99, 55, 53, 102,
      49, 100, 100, 52, 55, 50, 50, 52, 48, 51, 55, 50, 99, 99, 55, 48, 102, 55,
      100, 99, 48, 6, 59, 0, 70, 73, 34, 25, 72, 84, 84, 80, 95, 65, 67, 67, 69, 80,
      84, 95, 76, 65, 78, 71, 85, 65, 71, 69, 6, 59, 0, 84, 73, 34, 45, 54, 54, 101,
      97, 101, 57, 55, 49, 52, 57, 50, 57, 51, 56, 99, 50, 100, 99, 99, 50, 102, 98,
      49, 100, 100, 99, 56, 100, 55, 101, 99, 51, 49, 57, 54, 48, 51, 55, 100, 97,
      6, 59, 0, 70, 73, 34, 28, 108, 97, 115, 116, 95, 118, 105, 115, 105, 116, 101,
      100, 95, 97, 100, 109, 105, 110, 95, 112, 97, 103, 101, 6, 59, 0, 70, 34, 12,
      47, 101, 118, 101, 110, 116, 115, 73, 34, 26, 115, 101, 115, 115, 105, 111,
      110, 95, 105, 110, 95, 114, 101, 100, 105, 115, 95, 104, 97, 115, 104, 6, 59,
      0, 70, 84, 73, 34, 20, 115, 116, 114, 105, 112, 101, 95, 114, 101, 100, 105,
      114, 101, 99, 116, 6, 59, 0, 70, 73, 34, 32, 104, 116, 116, 112, 58, 47, 47,
      103, 105, 118, 105, 110, 103, 46, 112, 99, 111, 46, 100, 101, 118, 47, 115,
      101, 116, 117, 112, 6, 59, 0, 84, 73, 34, 35, 103, 114, 111, 117, 112, 115,
      95, 112, 101, 114, 115, 105, 115, 116, 101, 100, 95, 102, 105, 108, 116, 101,
      114, 95, 112, 97, 114, 97, 109, 115, 6, 59, 0, 70, 123, 7, 48, 73, 34, 0, 6,
      59, 0, 70, 58, 20, 108, 97, 115, 116, 95, 103, 114, 111, 117, 112, 95, 116,
      121, 112, 101, 48, 73, 34, 10, 102, 108, 97, 115, 104, 6, 59, 0, 84, 123, 7,
      73, 34, 12, 100, 105, 115, 99, 97, 114, 100, 6, 59, 0, 84, 91, 6, 73, 34, 19,
      110, 101, 120, 116, 95, 98, 114, 111, 97, 100, 99, 97, 115, 116, 6, 59, 0, 70,
      73, 34, 12, 102, 108, 97, 115, 104, 101, 115, 6, 59, 0, 84, 123, 6, 73, 34,
      19, 110, 101, 120, 116, 95, 98, 114, 111, 97, 100, 99, 97, 115, 116, 6, 59, 0,
      70, 48>>

    decoded_hash = ExMarshal.decode(binary)

    expected_hash = %{
      "session_id" => "a7d358648f16a2ed5d66dd2aba776a9973042a6f4d511a0e92d6bf8d0ce47526",
      "_csrf_token" => "eV5brJLsrPogkL/BlAJCmkLm3J1ceJf+QG6a/bUBcQk=",
      "account_center_user_id" => 1,
      "account_center_verified_user_id" => 1,
      "account_center_organization_id" => 1,
      "show_browser_warning" => false,
      "app_version_string" => "0.0",
      "session_in_redis" => true,
      "guest_ids" => [],
      "csrf" => "eV5brJLsrPogkL/BlAJCmkLm3J1ceJf+QG6a/bUBcQk=",
      "tracking" => %{
        "HTTP_USER_AGENT" => "dce5be285b4fc45c75f1dd472240372cc70f7dc0",
        "HTTP_ACCEPT_LANGUAGE" => "66eae971492938c2dcc2fb1ddc8d7ec3196037da"
      },
      "last_visited_admin_page" => "/events",
      "session_in_redis_hash" => true,
      "stripe_redirect" => "http://giving.pco.dev/setup",
      "groups_persisted_filter_params" => %{
        nil: "",
        last_group_type: nil
      },
      "flash" => %{
        "discard" => ["next_broadcast"],
        "flashes" => %{"next_broadcast" => nil}
      }
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

  test "set ruby objects to nil if nullify_objects is set to true" do
    cookie = "BAh7CUkiD3Nlc3Npb25faWQGOgZFVEkiJTRjODRkMzUzMTFkNTc2YWUwYjVkMmNjZjRhNjY4YzY2BjsAVEkiE3VzZXJfcmV0dXJuX3RvBjsAVCIGL0kiEF9jc3JmX3Rva2VuBjsARkkiMWVlQkRhOThqT2F2Q2dkTFRSemZkM2lpMTU4Ly9JckUxVEJrY1lwZVgwQnM9BjsARkkiCmZsYXNoBjsAVG86JUFjdGlvbkRpc3BhdGNoOjpGbGFzaDo6Rmxhc2hIYXNoCToKQHVzZWRvOghTZXQGOgpAaGFzaH0GOgphbGVydFRGOgxAY2xvc2VkRjoNQGZsYXNoZXN7BjsKSSI2WW91IG5lZWQgdG8gc2lnbiBpbiBvciBzaWduIHVwIGJlZm9yZSBjb250aW51aW5nLgY7AFQ6CUBub3cw"
    {:ok, ruby_encoded} = Base.decode64(cookie)

    Application.put_env(:ex_marshal, :nullify_objects, true)

    assert nil == ExMarshal.decode(ruby_encoded)["flash"]
  end

  test "raises exception for non-supported symbol when nullify object is set to false" do
    cookie = "BAh7CUkiD3Nlc3Npb25faWQGOgZFVEkiJTRjODRkMzUzMTFkNTc2YWUwYjVkMmNjZjRhNjY4YzY2BjsAVEkiE3VzZXJfcmV0dXJuX3RvBjsAVCIGL0kiEF9jc3JmX3Rva2VuBjsARkkiMWVlQkRhOThqT2F2Q2dkTFRSemZkM2lpMTU4Ly9JckUxVEJrY1lwZVgwQnM9BjsARkkiCmZsYXNoBjsAVG86JUFjdGlvbkRpc3BhdGNoOjpGbGFzaDo6Rmxhc2hIYXNoCToKQHVzZWRvOghTZXQGOgpAaGFzaH0GOgphbGVydFRGOgxAY2xvc2VkRjoNQGZsYXNoZXN7BjsKSSI2WW91IG5lZWQgdG8gc2lnbiBpbiBvciBzaWduIHVwIGJlZm9yZSBjb250aW51aW5nLgY7AFQ6CUBub3cw"
    {:ok, ruby_encoded} = Base.decode64(cookie)

    Application.put_env(:ex_marshal, :nullify_objects, false)

    assert_raise DecodeError, fn ->
      ExMarshal.decode(ruby_encoded)
    end
  end

  test "raises exception for non-supported symbol" do
    Application.put_env(:ex_marshal, :nullify_objects, false)

    ruby_encoded = File.read!("./test/fixtures/regexp.bin")

    assert_raise DecodeError, fn ->
      ExMarshal.decode(ruby_encoded)
    end
  end

  test "decode repetitive symbols" do
    value = <<4, 8, 123, 6, 73, 34, 6, 120, 6, 58, 6, 69, 84, 91, 7, 58, 12, 115, 117, 99, 99, 101, 115, 115, 59, 6>>

    assert %{"x" => [:success, :success]} == ExMarshal.decode(value)
  end

  test "decode long lists" do
    list_200 = File.read!("test/fixtures/200_items_list.bin")
    list_500 = File.read!("test/fixtures/500_items_list.bin")
    list_70000 = File.read!("test/fixtures/70000_items_list.bin")

    assert ExMarshal.decode(list_200) == Enum.to_list(1..200)
    assert ExMarshal.decode(list_500) == Enum.to_list(1..500)
    assert ExMarshal.decode(list_70000) == Enum.to_list(1..70000)
  end

  test "decode user object" do
    # Marshal.dump(Date.today).chars.map(&:ord)
    value = <<4, 8, 85, 58, 9, 68, 97, 116, 101, 91, 11, 105, 0, 105, 3, 72, 136, 37, 105, 0, 105, 0, 105, 0, 102, 12, 50, 50, 57, 57, 49, 54, 49>>

    assert {:Date, [0, 2459720, 0, 0, 0, 2299161.0]} == ExMarshal.decode(value)
  end
end
