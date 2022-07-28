defmodule ExMarshal do
  def encode(value) do
    ExMarshal.Encoder.encode(value)
  end

  def decode(value, opts \\ []) do
    ExMarshal.Decoder.decode(value, opts)
  end
end
