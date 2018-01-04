defmodule Nerves.Neopixel.NeopixelTest do
  use ExUnit.Case, async: false

  doctest Nerves.Neopixel

  alias Nerves.Neopixel
  alias Neopixel.HAL

  defp with_neopixel_stick(_) do
    Application.stop(:nerves_neopixel)
    {:ok, _pid} = HAL.start_link(config: neopixel_stick_config())
    :ok
  end

  describe "Nerves.Neopixel.set_pixel" do
    setup [:with_neopixel_stick]

    test "it works with RGB colors" do
      GenServer.call(HAL, :subscribe)
      Neopixel.set_pixel({1, 0}, {255, 0, 255})
      Neopixel.render()
      assert_receive "Called set_pixel(x: 1, y: 0, color: 0x00ff00ff)"
      assert_receive "Called render()"
      assert_receive "  [0][1]: 0x00ff00ff"
    end
  end

  defp neopixel_stick_config do
    [
      canvas: {8, 1},
      channels: [:channel1],
      channel1: [
        pin: 18,
        arrangement: [
          %{
            type: :strip,
            origin: {0, 0},
            count: 8,
            direction: :right
          }
        ]
      ]
    ]
  end
end
