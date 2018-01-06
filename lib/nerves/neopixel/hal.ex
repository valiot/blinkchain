defmodule Nerves.Neopixel.HAL do
  use GenServer

  alias Nerves.Neopixel.{
    Canvas,
    Channel,
    Config,
    Strip
  }

  require Logger

  def start_link(opts) do
    config = load_config(opts)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    pins = Enum.map(config.channels, fn ch -> ch.pin end)
    counts = Enum.map(config.channels, & Channel.total_count/1)
    args =
      Enum.zip(pins, counts)
      |> Enum.flat_map(fn {pin, count} -> [pin, count] end)
      |> Enum.map(& to_string/1)

    Logger.debug("Opening rpi_ws281x Port")
    port = Port.open({:spawn_executable, rpi_ws281x_path()}, [
      {:args, args},
      {:line, 1024},
      :use_stdio,
      :stderr_to_stdout,
      :exit_status
    ])
    send(self(), :init_canvas)
    {:ok, %{ config: config, port: port }}
  end

  # This is intended to be used for testing.
  # It causes Nerves.Neopixel.HAL to send feedback to the registered process
  # whenever it gets output from the rpi_ws281x Port.
  # It's a call instead of a cast so that we can synchronously make sure
  # it got registered before we move on to the next step.
  def handle_call(:subscribe, {from, _ref}, state) do
    {:reply, :ok, Map.put(state, :subscriber, from)}
  end

  # This is intended to be used for testing. It doesn't do anything useful
  # in a real application.
  def handle_cast(:print_topology, %{port: port} = state) do
    send_to_port("print_topology\n", port)
    {:noreply, state}
  end

  def handle_cast({:set_pixel, {x, y}, {r, g, b, w}}, %{port: port} = state) do
    send_to_port("set_pixel #{x} #{y} #{r} #{g} #{b} #{w}\n", port)
    {:noreply, state}
  end

  def handle_cast(:render, %{port: port} = state) do
    send_to_port("render\n", port)
    {:noreply, state}
  end

  def handle_info(:init_canvas, %{config: config, port: port} = state) do
    Logger.debug("Initializing canvas")
    config.canvas
    |> init_canvas()
    |> send_to_port(port)

    config.channels
    |> Enum.with_index()
    |> Enum.flat_map(fn {channel, channel_number} -> init_channel(channel_number, channel) end)
    |> Enum.each(& send_to_port(&1, port))

    {:noreply, state}
  end

  def handle_info({_port, {:data, {_, message}}}, state) do
    Logger.debug(fn -> "Reply from rpi_ws281x: <- #{inspect to_string(message)}" end)
    notify(state[:subscriber], to_string(message))
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, exit_status}}, state) do
    {:stop, "rpi_ws281x OS process died with status: #{inspect exit_status}", state}
  end

  def handle_info(message, state) do
    Logger.error("Unhandled message: #{inspect message}")
    {:noreply, state}
  end

  defp load_config(opts) do
    case Keyword.get(opts, :config) do
      nil -> Config.load()
      config -> Config.load(config)
    end
  end

  defp init_canvas(%Canvas{width: width, height: height}) do
    "init_canvas #{width} #{height}\n"
  end

  defp init_channel(channel_num, %Channel{arrangement: arrangement}) do
    arrangement
    |> with_pixel_offset()
    |> Enum.map(fn {offset, strip} -> init_pixels(channel_num, offset, strip) end)
  end

  defp init_pixels(channel_num, offset, %Strip{origin: {x, y}, count: count, direction: direction}) do
    {dx, dy} = case direction do
      :right -> {1, 0}
      :left -> {-1, 0}
      :down -> {0, 1}
      :up -> {0, -1}
    end
    "init_pixels #{channel_num} #{offset} #{x} #{y} #{count} #{dx} #{dy}\n"
  end

  defp with_pixel_offset(arrangement, offset \\0)
  defp with_pixel_offset([], _offset), do: []
  defp with_pixel_offset([strip | rest], offset) do
    [{offset, strip} | with_pixel_offset(rest, offset + strip.count)]
  end

  defp rpi_ws281x_path do
    Path.join(:code.priv_dir(:nerves_neopixel), "rpi_ws281x")
  end

  defp send_to_port(command, port) do
    Logger.debug("Sending to rpi_ws281x: -> #{inspect command}")
    Port.command(port, command)
  end

  defp notify(nil, _message), do: :ok
  defp notify(pid, message), do: send(pid, message)
end
