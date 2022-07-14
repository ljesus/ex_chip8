defmodule ExChip8.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.ViewPort

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @text_size 24

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(x, opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {:ok, %ViewPort.Status{size: {width, height}}} = ViewPort.info(opts[:viewport])

    # show the version of scenic and the glfw driver
    scenic_ver = Application.spec(:scenic, :vsn) |> to_string()
    glfw_ver = Application.spec(:scenic_driver_glfw, :vsn) |> to_string()

    graph =
      Graph.build(font: :roboto, font_size: @text_size)
      |> add_specs_to_graph([
        text_spec("scenic: v" <> scenic_ver, translate: {20, 40}),
        text_spec("glfw: v" <> glfw_ver, translate: {20, 40 + @text_size}),
        text_spec(@note, translate: {20, 120}),
        rect_spec({width, height})
      ])

    state = %{
      graph: graph,
      memory: ExChip8.Memory.new("/Users/luisjesus/Downloads/IBM Logo.ch8"),
      pc: 0x200
    }

    send(self(), :tick)

    {:ok, state, push: graph}
  end

  def handle_info(:tick, state) do
    case emulate(state.memory, state.pc) do
      {:ok, :ok} -> send(self(), :tick)
      {:error, :stop} -> IO.puts("stop")
    end

    {:noreply, %{state | pc: state.pc + 2}}
  end

  def handle_input(event, _context, state) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, state}
  end

  defp emulate(memory, pc) do
    try do
      opcode = binary_part(memory.data, pc, 2)
      execute(opcode)
      {:ok, :ok}
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
end
