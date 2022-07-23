defmodule ExChip8.Screen do
  import Scenic.Primitives
  import ExChip8.Helpers

  alias Scenic.Graph
  alias Scenic.Utilities.Texture
  alias __MODULE__

  @text_size 15
  @debug_width 130
  @num_bits 256

  defstruct [:ui_scale, :data]

  def new do
    %Screen{
      ui_scale: 10,
      data: empty_screen()
    }
  end

  def display(%ExChip8.Screen{} = screen, state, opcode) do
    Graph.build(font: :roboto, font_size: @text_size)
    |> add_specs_to_graph(debug_ui(state, opcode) ++ game_ui(screen, state))
  end

  def empty_screen(), do: :binary.copy(<<0x0>>, @num_bits)

  def checkered_screen() do
    0..(@num_bits - 1)
    |> Enum.to_list()
    |> Enum.reduce(<<>>, fn idx, acc ->
      case rem(div(idx * 8, 64), 2) do
        0 -> acc <> <<0::1, 1::1, 0::1, 1::1, 0::1, 1::1, 0::1, 1::1>>
        1 -> acc <> <<1::1, 0::1, 1::1, 0::1, 1::1, 0::1, 1::1, 0::1>>
      end
    end)
  end

  def set(%ExChip8.Screen{data: data} = screen, x, y, toggle) do
    byte_idx = trunc(div(x, 8) + y * (256 / 32))
    bit_idx = rem(x, 8)
    # IO.puts("#{x}, #{y} is at byte_idx #{byte_idx}, and its bit #{bit_idx} from this byte")
    first = binary_part(data, 0, byte_idx)
    modified_byte = binary_part(data, byte_idx, 1) |> modify_bit(bit_idx, toggle)

    second =
      binary_part(data, byte_idx + 1, byte_size(data) - byte_size(modified_byte) - byte_idx)

    # todo: collisions

    %{screen | data: first <> modified_byte <> second}
  end

  def modify_bit(byte, bit_idx, value) do
    f = 7 - bit_idx
    new_byte = <<0::size(bit_idx), value::1, 0::size(f)>>
    modified = :crypto.exor(byte, new_byte)
    modified
  end

  defp debug_ui(%{pc: pc, memory: memory, i: i, v: v, stack: stack} = _state, opcode) do
    origin_x = 20
    origin_y = 20

    [
      rect_spec({@debug_width, 320}, stroke: {1, :white}, translate: {5, 5}),
      text_spec("pc: " <> hex_to_string(pc), translate: {origin_x, origin_y}),
      text_spec("opcode: " <> display_binary(opcode), translate: {origin_x, origin_y + @text_size}),
      text_spec("mem size: #{byte_size(memory.data)}",
        translate: {origin_x, origin_y + @text_size * 2}
      ),
      text_spec("i: " <> hex_to_string(i), translate: {origin_x, origin_y + @text_size * 3}),
      text_spec("stack top: " <> hex_to_string(List.first(stack)),
        translate: {origin_x, origin_y + @text_size * 4}
      ),
      text_spec(
        Enum.with_index(v)
        |> Enum.reduce("", fn {vx, idx}, acc ->
          acc <> "v#{hex_to_string(idx)}: " <> hex_to_string(vx) <> "\n"
        end),
        translate: {origin_x, origin_y + @text_size * 5}
      )
    ]
  end

  defp game_ui(%ExChip8.Screen{ui_scale: ui_scale, data: data}, _state) do
    texture =
      0..(@num_bits - 1)
      |> Enum.to_list()
      |> Enum.reduce(Texture.build!(:rgb, 64 * ui_scale, 32 * ui_scale), fn byte_idx, acc ->
        get_bits(binary_part(data, byte_idx, 1))
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {value, idx2}, acc ->
          x = rem(byte_idx * 8 + idx2, 64)
          y = div(byte_idx * 8 + idx2, 64)
          # IO.puts("Drawing #{byte_idx}: #{x}, #{y}")

          case value do
            <<0::1>> -> draw_pixel(acc, ui_scale, x, y, :black)
            <<1::1>> -> draw_pixel(acc, ui_scale, x, y, :white)
          end
        end)
      end)

    Scenic.Cache.Dynamic.Texture.put("screen", texture)

    [
      rect_spec({64 * ui_scale, 32 * ui_scale},
        stroke: {1, :white},
        fill: {:dynamic, "screen"},
        translate: {@debug_width + 10, 5}
      )
    ]
  end

  defp draw_pixel(texture, ui_scale, x, y, color) do
    initial_x = x * ui_scale
    initial_y = y * ui_scale

    initial_x..(initial_x + ui_scale)
    |> Enum.to_list()
    |> Enum.reduce(texture, fn x, acc_x ->
      initial_y..(initial_y + ui_scale)
      |> Enum.to_list()
      |> Enum.reduce(acc_x, fn y, acc_y ->
        Texture.put!(acc_y, x, y, color)
      end)
    end)
  end

  defp hex_to_string(nil), do: "-"
  defp hex_to_string(mem_address), do: "0x#{Integer.to_string(mem_address, 16)} (#{mem_address})"
  defp display_binary(binary), do: binary |> Base.encode16()
end
