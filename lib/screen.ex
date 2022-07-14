defmodule ExChip8.Screen do
  import Scenic.Primitives

  alias Scenic.Graph
  alias Scenic.Utilities.Texture
  alias __MODULE__

  @text_size 17
  @debug_width 130

  defstruct ui_scale: 10

  def new do
    %Screen{}
  end

  def display(%ExChip8.Screen{ui_scale: ui_scale}, state, opcode) do
    Graph.build(font: :roboto, font_size: @text_size)
    |> add_specs_to_graph(debug_ui(state, opcode) ++ game_ui(ui_scale, state))
  end

  defp debug_ui(%{pc: pc, memory: memory} = _state, opcode) do
    [
      rect_spec({@debug_width, 320}, stroke: {1, :white}, translate: {5, 5}),
      text_spec("pc: " <> hex_to_string(pc), translate: {20, 40}),
      text_spec("opcode: " <> display_binary(opcode), translate: {20, 40 + @text_size}),
      text_spec("mem size: #{byte_size(memory.data)}", translate: {20, 40 + @text_size * 2})
    ]
  end

  defp game_ui(ui_scale, _state) do
    texture =
      Texture.build!(:rgb, 64 * ui_scale, 32 * ui_scale)
      |> draw_pixel(ui_scale, 0, 0, :red)
      |> draw_pixel(ui_scale, 0, 31, :blue)
      |> draw_pixel(ui_scale, 63, 0, :gray)
      |> draw_pixel(ui_scale, 63, 31, :white)

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

  defp hex_to_string(mem_address), do: "0x" <> Integer.to_string(mem_address, 16)
  defp display_binary(binary), do: binary |> Base.encode16()
end
