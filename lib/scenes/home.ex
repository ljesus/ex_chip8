defmodule ExChip8.Scene.Home do
  use Scenic.Scene

  require Logger

  alias Scenic.Graph

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    graph = Graph.build()

    interpreter =
      ExChip8.Interpreter.new("/Users/luisjesus/Downloads/Space Invaders [David Winter].ch8")

    send(self(), :tick)

    {:ok, %{interpreter: interpreter, graph: graph}, push: graph}
  end

  def handle_info(
        :tick,
        %{
          interpreter: %ExChip8.Interpreter{screen: screen, running: running} = interpreter,
          graph: graph
        } = state
      ) do
    case running do
      true ->
        {new_interpreter, opcode} =
          case ExChip8.Interpreter.cycle(interpreter) do
            {:ok, %{interpreter: interpreter, opcode: opcode}} ->
              {interpreter, opcode}

            {:error, :stop} ->
              {interpreter, nil}
          end

        graph =
          case opcode do
            nil ->
              graph

            opcode ->
              ExChip8.Screen.display(screen, interpreter, opcode)
          end

        send(self(), :tick)

        {:noreply, %{state | interpreter: %{new_interpreter | running: true}, graph: graph},
         push: graph}

      _ ->
        # IO.puts("Stopped")
        {:noreply, state}
    end
  end

  def handle_input(event, _context, %{interpreter: interpreter} = state) do
    # Logger.info("Received event: #{inspect(event)}")

    case event do
      {:key, {" ", :press, 0}} ->
        send(self(), :tick)
        {:noreply, %{state | interpreter: %{interpreter | running: true}}}

      _ ->
        {:noreply, state}
    end
  end
end
