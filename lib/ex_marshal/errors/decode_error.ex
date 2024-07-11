defmodule ExMarshal.Errors.DecodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:ivar_string_only, term} ->
        "only string ivars are supported: #{inspect(term)}"
      {:invalid_encoding, term} ->
        "invalid encoding: #{inspect(term)}"
      {:not_supported, term} ->
        "term which starts with the following symbol is not supported: #{inspect(term)}"
    end
  end
end
