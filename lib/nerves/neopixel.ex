defmodule Nerves.Neopixel do
  alias Nerves.Neopixel.HAL

  require Logger

  @moduledoc """
  # `Nerves.Neopixel`
  """

  def set_pixel({x, y}, {r, g, b}) do
    GenServer.cast(HAL, {:set_pixel, {x, y}, {r, g, b, 0}})
  end
  def set_pixel({x, y}, {r, g, b, w}) do
    GenServer.cast(HAL, {:set_pixel, {x, y}, {r, g, b, w}})
  end

  def fill({x, y}, width, height, {r, g, b}) do
    GenServer.cast(HAL, {:fill, {x, y}, width, height, {r, g, b, 0}})
  end
  def fill({x, y}, width, height, {r, g, b, w}) do
    GenServer.cast(HAL, {:fill, {x, y}, width, height, {r, g, b, w}})
  end

  def render, do: GenServer.cast(HAL, :render)
end
