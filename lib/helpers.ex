defmodule ExChip8.Helpers do
  def get_bits(data) do
    bits_in_binary([], data)
  end

  defp bits_in_binary(bits, <<>>), do: bits
  defp bits_in_binary(bits, <<x::bits-1, rest::bits>>), do: bits_in_binary(bits ++ [x], rest)
end
