# ExMarshal

`ExMarshal` encodes and decodes Elixir terms according to [Ruby Marshal](http://docs.ruby-lang.org/en/2.2.0/marshal_rdoc.html) format.

Currently supported Ruby types are `nil`, `false`, `true`, `Fixnum`, `Bignum`, `BigDecimal`, `Float`, `Symbol`, `String`, `Array`, `Hash`.

## Why?

Once you decide to integrate small Elixir tool into big-old-legacy Ruby system, chances are that you need to interact with [Memcached](http://memcached.org). As soon as Ruby code writes something into Memcached, most likely Ruby uses [dalli](https://github.com/mperham/dalli) gem. And `Dalli` uses [Ruby Marshal](http://docs.ruby-lang.org/en/2.2.0/marshal_rdoc.html) by default. 

## Installation

Add ExMarshal as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:ex_marshal, "~> 0.0.1"}]
end
```

