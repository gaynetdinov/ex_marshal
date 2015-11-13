defmodule ExMarshal do
  def encode(value) do
    ExMarshal.Encoder.encode(value)
  end

  def decode(value) do
    ExMarshal.Decoder.decode(value)
  end
end
