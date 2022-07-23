defmodule ExChip8.Keyboard do
  alias __MODULE__

  defstruct [:keys]

  def new() do
    %Keyboard{
      keys: 0x0..0xF |> Enum.map(fn _i -> false end)
    }
  end

  def key_pressed(%Keyboard{keys: keys} = keyboard, key) do
    %{
      keyboard
      | keys: List.update_at(keys, key, fn _ -> true end)
    }
  end

  def key_released(%Keyboard{keys: keys} = keyboard, key) do
    %{
      keyboard
      | keys: List.update_at(keys, key, fn _ -> false end)
    }
  end

  def is_key_pressed(%Keyboard{keys: keys}, key) do
    Enum.at(keys, key)
  end
end
