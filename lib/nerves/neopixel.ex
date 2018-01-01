defmodule Nerves.Neopixel do
  require Logger

  @moduledoc """
  # `Nerves.Neopixel`
  """

  def render({_, _} = data) do
    render(0, data)
  end

  def render(channel, {_, _} = data) do
    GenServer.call(__MODULE__, {:render, channel, data})
  end

  def handle_call({:render, channel, {brightness, data}}, _from, s) do
    data = ws2811_brg(data)

    payload =
      {channel, {brightness, data}}
      |> :erlang.term_to_binary()

    send(s.port, {self(), {:command, payload}})
    {:reply, :ok, s}
  end

  def handle_info({_port, {:exit_status, exit_status}}, state) do
    {:stop, "rpi_ws281x OS process died with status: #{exit_status}", state}
  end

  defp ws2811_brg(data) when is_list(data) do
    Enum.reduce(data, <<>>, fn {r, g, b}, acc ->
      acc <> <<b::size(8), r::size(8), g::size(8), 0x00::size(8)>>
    end)
  end
end
