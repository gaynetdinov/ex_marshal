defmodule ExMarshal.Errors.EncodeError do
  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:not_supported, term} ->
        "the following type is not supported: #{inspect(term)}"
    end
  end
end
