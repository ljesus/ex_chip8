defmodule ExChip8.Scene.Home do
  use Scenic.Scene
  use Bitwise
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
      v: 0x0..0xF |> Enum.map(fn _i -> 0x0 end),
      stack: []
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
  defp execute(state, <<0x00E0::16>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] CLS")
    %{state | screen: ExChip8.Screen.new()}
  end

  # 00EE - RET
  defp execute(%{stack: [top | rest]} = state, <<0x00EE::16>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] RET")
    %{state | pc: top, stack: rest}
  end

  # Annn - LD I, addr
  defp execute(state, <<0xA::4, nnn::12>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] LD I,  #{nnn}")
    %{state | i: nnn}
  end

  # 1nnn - JP addr
  defp execute(state, <<0x1::4, nnn::12>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] JP #{nnn}")
    %{state | pc: nnn}
  end

  # 2nnn - CALL addr
  defp execute(%{stack: stack, pc: pc} = state, <<0x2::4, nnn::12>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] CALL #{nnn}")
    %{state | pc: nnn, stack: [pc | stack]}
  end

  # 3xkk - SE Vx, byte
  defp execute(%{pc: pc, v: v} = state, <<0x3::4, x::4, kk::8>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] SE V#{x}, #{kk}")

    case Enum.at(v, x) do
      ^kk -> %{state | pc: pc + 2}
      _ -> state
    end
  end

  # 4xkk - SNE Vx, byte
  defp execute(%{pc: pc, v: v} = state, <<0x4::4, x::4, kk::8>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] SNE V#{x}, #{kk}")

    case Enum.at(v, x) do
      ^kk -> state
      _ -> %{state | pc: pc + 2}
    end
  end

  # 5xy0 - SE Vx, Vy
  defp execute(%{pc: pc, v: v} = state, <<0x5::4, x::4, y::4, 0x0::4>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] SE V#{x}, V#{y}")

    vy = Enum.at(v, y)

    case Enum.at(v, x) do
      ^vy -> %{state | pc: pc + 2}
      _ -> state
    end
  end

  # 6xkk - LD Vx, byte
  defp execute(%{v: v} = state, <<0x6::4, x::4, kk::8>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] LD V#{x} #{kk}")
    %{state | v: update_v(v, x, kk)}
  end

  # 8xy0 - LD Vx, Vy
  defp execute(%{v: v} = state, <<0x8::4, x::4, y::4, 0::4>> = opcode) do
    IO.puts("[#{print_instruction(opcode)}] LD V#{x} V#{y}")
    %{state | v: update_v(v, x, Enum.at(v, y))}
  end

  # Dxyn - DRW Vx, Vy, nibble
  defp execute(
         %{v: v, i: i, memory: memory, screen: screen} = state,
         <<0xD::4, x::4, y::4, n::4>> = opcode
       ) do
    IO.puts("[#{print_instruction(opcode)}] DRW V#{x}, V#{y}, #{n}")
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
         <<0x7::4, x::4, kk::8>> = opcode
       ) do
    IO.puts("[#{print_instruction(opcode)}] ADD V#{x}, #{kk}")
    %{state | v: update_v(v, x, Enum.at(v, x) + kk)}
  end

  # Cxkk - RND Vx, byte
  defp execute(
         %{v: v} = state,
         <<0xC::4, x::4, kk::8>> = opcode
       ) do
    byte = :rand.uniform(256) - 1
    IO.puts("[#{print_instruction(opcode)}] RND V#{x}, #{byte}")
    %{state | v: update_v(v, x, byte &&& kk)}
  end

  # Fx1E - ADD I, Vx
  defp execute(
         %{i: i, v: v} = state,
         <<0xF::4, x::4, 0x1E::8>> = opcode
       ) do
    IO.puts("[#{print_instruction(opcode)}] ADD I, V#{x}")
    %{state | i: Enum.at(v, x) + i}
  end

  # Fx55 - ADD I, Vx
  defp execute(
         %{i: i, v: v, memory: memory} = state,
         <<0xF::4, x::4, 0x55::8>> = opcode
       ) do
    IO.puts("[#{print_instruction(opcode)}] LD [I], Vx")

    %{
      state
      | memory:
          Enum.reduce(Enum.with_index(v), memory, fn {v, idx}, acc ->
            if x <= idx do
              ExChip8.Memory.write(acc, i + idx, v)
            else
              acc
            end
          end)
    }
  end

  defp execute(state, <<0x0000::16>>), do: state

  defp execute(state, instruction) do
    IO.puts("TO IMPLEMENT: #{print_instruction(instruction)}")
    state
  end

  defp print_instruction(instruction), do: instruction |> Base.encode16()

  defp render(%{screen: screen} = state, opcode) do
    ExChip8.Screen.display(screen, state, opcode)
  end

  defp update_v(registers, index, value), do: List.update_at(registers, index, fn _ -> value end)
end
