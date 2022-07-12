defmodule ExChip8.Memory do
  alias __MODULE__

  # http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#2.1
  # 4KB (4,096 bytes) of RAM, from location 0x000 (0) to 0xFFF (4095)
  #
  # Memory Map:
  # +---------------+= 0xFFF (4095) End of Chip-8 RAM
  # |               |
  # |               |
  # |               |
  # |               |
  # |               |
  # | 0x200 to 0xFFF|
  # |     Chip-8    |
  # | Program / Data|
  # |     Space     |
  # |               |
  # |               |
  # |               |
  # +- - - - - - - -+= 0x600 (1536) Start of ETI 660 Chip-8 programs
  # |               |
  # |               |
  # |               |
  # +---------------+= 0x200 (512) Start of most Chip-8 programs
  # | 0x000 to 0x1FF|
  # | Reserved for  |
  # |  interpreter  |
  # +---------------+= 0x000 (0) Start of Chip-8 RAM

  defstruct [:data]

  def new do
    %Memory{
      data: :binary.copy(<<0x0>>, 4096)
    }
    |> init_fonts()
  end

  defp init_fonts(%Memory{} = memory) do
    write(memory, 0x000, <<
      # 0
      0xF0,
      0x90,
      0x90,
      0x90,
      0xF0,
      # 1
      0x20,
      0x60,
      0x20,
      0x20,
      0x70,
      # 2
      0xF0,
      0x10,
      0xF0,
      0x80,
      0xF0,
      # 3
      0xF0,
      0x10,
      0xF0,
      0x10,
      0xF0,
      # 4
      0x90,
      0x90,
      0xF0,
      0x10,
      0x10,
      # 5
      0xF0,
      0x80,
      0xF0,
      0x10,
      0xF0,
      # 6
      0xF0,
      0x80,
      0xF0,
      0x90,
      0xF0,
      # 7
      0xF0,
      0x10,
      0x20,
      0x40,
      0x40,
      # 8
      0xF0,
      0x90,
      0xF0,
      0x90,
      0xF0,
      # 9
      0xF0,
      0x90,
      0xF0,
      0x10,
      0xF0,
      # A
      0xF0,
      0x90,
      0xF0,
      0x90,
      0x90,
      # B
      0xE0,
      0x90,
      0xE0,
      0x90,
      0xE0,
      # C
      0xF0,
      0x80,
      0x80,
      0x80,
      0xF0,
      # D
      0xE0,
      0x90,
      0x90,
      0x90,
      0xE0,
      # E
      0xF0,
      0x80,
      0xF0,
      0x80,
      0xF0,
      # F
      0xF0,
      0x80,
      0xF0,
      0x80,
      0x80
    >>)
  end

  @doc """
  Writes a binary string to the memory at the given address.
  """
  def write(%Memory{data: data} = memory, address, value)
      when is_integer(address) and is_bitstring(value) do
    first = binary_part(data, 0, address)
    value_length = byte_size(value)
    second = binary_part(data, address + value_length, byte_size(data) - value_length)
    %{memory | data: first <> value <> second}
  end

  def debug(%Memory{data: data}) do
    string = Base.encode16(data)
    for(<<x::binary-2 <- string>>, do: x) |> Enum.join(" ") |> IO.puts()
  end
end
