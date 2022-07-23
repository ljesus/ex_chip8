defmodule ExChip8.Scene.Home do
  use Scenic.Scene

  require Logger

  alias Scenic.Graph

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    graph = Graph.build()

    interpreter = ExChip8.Interpreter.new("/Users/luisjesus/Downloads/IBM Logo.ch8")

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

  def handle_input(event, _context, %{interpreter: %{keyboard: keyboard} = interpreter} = state) do
    # Logger.info("Received event: #{inspect(event)}")

    # 1	2	3	4 -> 1 2 3 C
    # Q	W	E	R -> 4 5 6 D
    # A	S	D	F -> 7 8 9 E
    # Z	X	C	V -> A 0 B F

    mapping = %{
      "1": 0x1,
      "2": 0x2,
      "3": 0x3,
      "4": 0xC,
      Q: 0x4,
      W: 0x5,
      E: 0x6,
      R: 0xD,
      A: 0x7,
      S: 0x8,
      D: 0x9,
      F: 0xE,
      Z: 0xA,
      X: 0x0,
      C: 0xB,
      V: 0xF
    }

    # Logger.info("Received event: #{inspect(event)}.")

    case event do
      {:key, {" ", :press, 0}} ->
        send(self(), :tick)
        {:noreply, %{state | interpreter: %{interpreter | running: true}}}

      {:key, {key, :press, 0}} ->
        case Map.has_key?(mapping, String.to_atom(key)) do
          true ->
            {:noreply,
             %{
               state
               | interpreter: %{
                   interpreter
                   | keyboard:
                       ExChip8.Keyboard.key_pressed(keyboard, mapping[String.to_atom(key)])
                 }
             }}

          false ->
            IO.inspect(mapping: mapping, key: key)
            {:noreply, state}
        end

      {:key, {key, :release, 0}} ->
        case Map.has_key?(mapping, String.to_atom(key)) do
          true ->
            {:noreply,
             %{
               state
               | interpreter: %{
                   interpreter
                   | keyboard:
                       ExChip8.Keyboard.key_released(keyboard, mapping[String.to_atom(key)])
                 }
             }}

          false ->
            {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end
end
