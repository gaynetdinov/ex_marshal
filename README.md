# ExMarshal

`ExMarshal` encodes and decodes Elixir terms according to [Ruby Marshal](http://docs.ruby-lang.org/en/2.2.0/marshal_rdoc.html) format.

Currently supported Ruby types are `nil`, `false`, `true`, `Fixnum`, `Bignum`, `BigDecimal`, `Float`, `Symbol`, `String`, `Array`, `Hash`.

## Why?

Once you decide to integrate small Elixir tool into big-old-legacy Ruby system, chances are that you need to interact with [Memcached](http://memcached.org). As soon as Ruby code writes something into Memcached, most likely Ruby uses [dalli](https://github.com/mperham/dalli) gem. And `Dalli` uses [Ruby Marshal](http://docs.ruby-lang.org/en/2.2.0/marshal_rdoc.html) by default.

## Installation

Add ExMarshal as a dependency to your `mix.exs` file:

```elixir
def deps do
  [{:ex_marshal, "~> 0.0.1"}]
end
```

## Usage

```elixir
iex(1)> ExMarshal.decode(<<4, 8, 91, 8, 105, 6, 105, 7, 105, 8>>)
[1, 2, 3]
iex(2)> ExMarshal.encode([1, 2, 3])
<<4, 8, 91, 8, 105, 6, 105, 7, 105, 8>>
iex(3)>
```

## ExMarshal with Memcache.Client

Of course it's possible to use `ExMarshal` on its own, but the main reason why `ExMarshal` was created is to work with `Memcached`. Here is how `ExMarshal` can be used with [Memcache.Client](https://github.com/tsharju/memcache_client):

```elixir

defmodule Memcache.Client.Transcoder.Ruby do
  @behaviour Memcache.Client.Transcoder

  @ruby_type_flag 0x0001

  def encode_value(value) do
    {ExMarshal.encode(value), @ruby_type_flag}
  end

  def decode_value(value, @ruby_type_flag) do
    ExMarshal.decode(value)
  end

  def decode_value(_value, data_type) do
    {:error, {:invalid_data_type, data_type}}
  end
end
```

Then tell `Memcache.Client` to use this transcoder:

```elixir
config :memcache_client,
  transcoder: Memcache.Client.Transcoder.Ruby
```

### Example

#### Read

Ruby side

```ruby
:1 > dc = Dalli::Client.new('localhost:11211')
:2 > dc.set("str", "hello elixir")
 => true

```

Elixir side

```elixir
iex(1)> Memcache.Client.get("str")
%Memcache.Client.Response{cas: 184, data_type: 1, extras: <<0, 0, 0, 1>>,
 key: "", status: :ok, value: "hello elixir"}
```

#### Write

Elixir side

```elixir
iex(1)> Memcache.Client.set("str", "hello ruby")
%Memcache.Client.Response{cas: 185, data_type: nil, extras: "", key: "",
 status: :ok, value: ""}
```

Ruby side

```ruby
:1 > dc = Dalli::Client.new('localhost:11211')
:2 > dc.get("str")
 => "hello ruby"
```
