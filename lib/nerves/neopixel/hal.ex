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
    GenServer.start_link(__MODULE__, Config.load(), opts)
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
    Logger.info("Output from rpi_ws281x: #{message}")
    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.error("Unhandled message: #{inspect message}")
    {:noreply, state}
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

  defp with_pixel_offset([], _offset), do: []
  defp with_pixel_offset([strip | rest], offset \\ 0) do
    [{offset, strip} | with_pixel_offset(rest, offset + strip.count)]
  end

  defp rpi_ws281x_path do
    Path.join(:code.priv_dir(:nerves_neopixel), "rpi_ws281x")
  end

  defp send_to_port(command, port) do
    Logger.debug("Sending to Port: #{inspect command}")
    Port.command(port, command)
  end
end
