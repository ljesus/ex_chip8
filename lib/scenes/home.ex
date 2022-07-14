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
      screen: ExChip8.Screen.new()
    }

    send(self(), :tick)

    {:ok, state, push: graph}
  end

  def handle_info(:tick, state) do
    case state do
      %{stopped: false} ->
        opcode =
          case emulate(state.memory, state.pc) do
            {:ok, opcode} ->
              opcode

            {:error, :stop} ->
              nil
          end

        graph =
          case opcode do
            nil ->
              state.graph

            opcode ->
              render(state, opcode)
          end

        send(self(), :tick)

        {:noreply, %{state | pc: state.pc + 2, graph: graph, stopped: true}, push: graph}

      _ ->
        IO.puts("Stopped")
        {:noreply, state}
    end
  end

  def handle_input(event, _context, state) do
    Logger.info("Received event: #{inspect(event)}")

    case event do
      {:key, {" ", :press, 0}} ->
        send(self(), :tick)
        {:noreply, %{state | stopped: false}}

      _ ->
        {:noreply, state}
    end
  end

  defp emulate(memory, pc) do
    try do
      # All instructions are 2 bytes long and are stored most-significant-byte first.
      opcode = binary_part(memory.data, pc, 2)
      execute(opcode)
      {:ok, opcode}
    rescue
      err ->
        IO.inspect(err)
        {:error, :stop}
    end
  end

  defp execute(<<0x00E0::16>>) do
    IO.puts("CLEAR DISPLAY")
  end

  defp execute(<<0x0000::16>>), do: :ignore

  defp execute(instruction) do
    IO.puts("TO IMPLEMENT: " <> (instruction |> Base.encode16()))
  end

  defp render(%{screen: screen} = state, opcode) do
    ExChip8.Screen.display(screen, state, opcode)
  end
end
