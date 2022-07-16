defmodule ExChip8.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph

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

        {:noreply, %{new_state | pc: state.pc + 2, graph: graph, stopped: true}, push: graph}

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
      new_state = execute(state, opcode)
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

  # Annn - JP addr
  defp execute(state, <<0xA::4, nnn::12>>) do
    IO.puts("JP #{nnn}")
    %{state | i: nnn}
  end

  # 6xkk - LD Vx, byte
  defp execute(%{v: v} = state, <<0x6::4, x::4, kk::8>>) do
    IO.puts("LD V#{x} #{kk}")
    %{state | v: update_v(v, x, kk)}
  end

  # Dxyn - DRW Vx, Vy, nibble
  defp execute(%{v: v, i: i} = state, <<0xD::4, x::4, y::4, n::4>>) do
    IO.puts("DRW V#{x}, V#{y}, #{n}")
    # todo: modulo
    x_coord = Enum.at(v, x)
    y_coord = Enum.at(v, y)
    initial_address = i
    IO.inspect(x: x_coord, y: y_coord)
    state
  end

  defp execute(state, <<0x0000::16>>), do: state

  defp execute(state, instruction) do
    IO.puts("TO IMPLEMENT: " <> (instruction |> Base.encode16()))
    state
  end

  defp render(%{screen: screen} = state, opcode) do
    ExChip8.Screen.display(screen, state, opcode)
  end

  defp update_v(registers, index, value), do: List.update_at(registers, index, fn _ -> value end)
end
