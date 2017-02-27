defmodule Nerves.Neopixel.Channel do
  defstruct [
    pin: 0, count: 0, brightness: 0,
    data: [], invert: false, type: :bgr]
end
