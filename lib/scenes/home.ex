defmodule ExChip8.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  import ExChip8.Helpers

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    graph = Graph.build()

    state = %{
      graph: graph,
      memory: ExChip8.Memory.new("/Users/luisjesus/Downloads/IBM Logo.ch8"),
      pc: 0x200,
      stopped: false,
      screen: ExChip8.Screen.new(),
      i: 0x000,
      v: 0x0..0xF |> Enum.map(fn _i -> 0x0 end)
    }

    send(self(), :tick)

    {:ok, state, push: graph}
  end

  def handle_info(:tick, state) do
    case state do
      %{stopped: false} ->
        {new_state, opcode} =
          case emulate(state) do
            {:ok, %{state: state, opcode: opcode}} ->
              {state, opcode}

            {:error, :stop} ->
              {state, nil}
          end

        graph =
          case opcode do
            nil ->
              new_state.graph

            opcode ->
              render(new_state, opcode)
          end

        send(self(), :tick)

        {:noreply, %{new_state | pc: new_state.pc, graph: graph, stopped: true}, push: graph}

      _ ->
        # IO.puts("Stopped")
        {:noreply, state}
    end
  end

  def handle_input(event, _context, state) do
    # Logger.info("Received event: #{inspect(event)}")

    case event do
      {:key, {" ", :press, 0}} ->
        send(self(), :tick)
        {:noreply, %{state | stopped: false}}

      _ ->
        {:noreply, state}
    end
  end

  defp emulate(%{memory: memory, pc: pc} = state) do
    try do
      # All instructions are 2 bytes long and are stored most-significant-byte first.
      opcode = binary_part(memory.data, pc, 2)
      new_state = execute(%{state | pc: pc + 2}, opcode)
      {:ok, %{state: new_state, opcode: opcode}}
    rescue
      err ->
        IO.inspect(err)
        {:error, :stop}
    end
  end

  # 00E0 - CLS
  defp execute(state, <<0x00E0::16>>) do
    IO.puts("CLS")
    state
  end

  # Annn - LD I, addr
  defp execute(state, <<0xA::4, nnn::12>>) do
    IO.puts("LD I,  #{nnn}")
    %{state | i: nnn}
  end

  # 1nnn - JP addr
  defp execute(state, <<0x1::4, nnn::12>>) do
    IO.puts("JP #{nnn}")
    %{state | pc: nnn}
  end

  # 6xkk - LD Vx, byte
  defp execute(%{v: v} = state, <<0x6::4, x::4, kk::8>>) do
    IO.puts("LD V#{x} #{kk}")
    %{state | v: update_v(v, x, kk)}
  end

  # Dxyn - DRW Vx, Vy, nibble
  defp execute(
         %{v: v, i: i, memory: memory, screen: screen} = state,
         <<0xD::4, x::4, y::4, n::4>>
       ) do
    IO.puts("DRW V#{x}, V#{y}, #{n}")
    x_coord = rem(Enum.at(v, x), 63)
    y_coord = rem(Enum.at(v, y), 31)

    new_screen =
      0..(n - 1)
      |> Enum.to_list()
      |> Enum.reduce(screen, fn n, new_screen ->
        # Get the Nth byte of sprite data, counting from the memory address in the I register (I is not incremented)
        sprite_data = ExChip8.Memory.read(memory, i + n, 1)
        #  IO.puts("Got sprite data for byte #{n}")
        # For each of the 8 pixels/bits in this sprite row:
        get_bits(sprite_data)
        |> Enum.with_index()
        |> Enum.reduce(new_screen, fn {bit, idx}, new_screen ->
          # IO.inspect(bit: bit, idx: idx, x: x_coord + idx, y: y_coord + n)
          # IO.puts("Drawing bit #{bit} at #{idx} with coord #{x_coord + idx}, #{y_coord + n}")
          # If the current pixel in the sprite row is on and the pixel at coordinates X,Y on the screen is also on, turn off the pixel and set VF to 1
          # Or if the current pixel in the sprite row is on and the screen pixel is not, draw the pixel at the X and Y coordinates
          # If you reach the right edge of the screen, stop drawing this row
          # Increment X (VX is not incremented)
          # Increment Y (VY is not incremented)
          # Stop if you reach the bottom edge of the screen
          case bit do
            <<1::1>> -> ExChip8.Screen.set(new_screen, x_coord + idx, y_coord + n, 1)
            _ -> new_screen
          end
        end)
      end)

    %{state | screen: new_screen}
  end

  # 7xkk - ADD Vx, byte
  defp execute(
         %{v: v} = state,
         <<0x7::4, x::4, kk::8>>
       ) do
    IO.puts("ADD V#{x}, #{kk}")
    %{state | v: update_v(v, x, Enum.at(v, x) + kk)}
  end

  defp execute(state, <<0x0000::16>>), do: state

  defp execute(state, instruction) do
    IO.puts("TO IMPLEMENT: " <> (instruction |> Base.encode16()))
  end

  defp render(%{screen: screen} = state, opcode) do
    ExChip8.Screen.display(screen, state, opcode)
  end

  defp update_v(registers, index, value), do: List.update_at(registers, index, fn _ -> value end)
end
