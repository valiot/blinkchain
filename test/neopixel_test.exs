defmodule Nerves.Neopixel.NeopixelTest do
  # We have to use async: false for these because the HAL wants to register its
  # name globally, so we can only run one at a time.
  use ExUnit.Case, async: false

  doctest Nerves.Neopixel

  alias Nerves.Neopixel
  alias Neopixel.HAL

  # Arrangement looks like this:
  # Y  X: 0  1  2  3  4  5  6  7
  # 0  [  0  1  2  3  4  5  6  7 ] <- Adafruit NeoPixel Stick on Channel 1 (offset 0)
  #    |-------------------------|
  # 1  |  0  1  2  3  4  5  6  7 |
  # 2  |  8  9 10 11 12 13 14 15 | <- Pimoroni Unicorn pHat on Channel 2 (offset 1)
  # 3  | 16 17 18 19 20 21 22 23 |
  # 4  | 24 25 26 27 28 29 30 31 |
  #    |-------------------------|
  defp with_neopixel_stick_and_unicorn_phat(_) do
    Application.stop(:nerves_neopixel)
    {:ok, _pid} = HAL.start_link(config: neopixel_stick_and_unicorn_phat_config())
    GenServer.call(HAL, :subscribe)
    flush()
    :ok
  end

  describe "Nerves.Neopixel.set_pixel" do
    setup [:with_neopixel_stick_and_unicorn_phat]

    test "it works with RGB colors" do
      Neopixel.set_pixel({0, 0}, {255, 0, 128})
      assert_receive "Called set_pixel(x: 0, y: 0, color: 0x00ff0080)"

      Neopixel.render()
      assert_receive "Called render()"
      assert_receive "  [0][0]: 0x00ff0080"
    end

    test "it works with RGBW colors" do
      Neopixel.set_pixel({0, 0}, {255, 0, 128, 64})
      assert_receive "Called set_pixel(x: 0, y: 0, color: 0x40ff0080)"

      Neopixel.render()
      assert_receive "Called render()"
      assert_receive "  [0][0]: 0x40ff0080"
    end

    test "it renders the pixel in the correct location on a strip" do
      Neopixel.set_pixel({6, 0}, {255, 0, 128, 64})
      assert_receive "Called set_pixel(x: 6, y: 0, color: 0x40ff0080)"

      Neopixel.render()
      assert_receive "Called render()"
      assert_receive "  [0][6]: 0x40ff0080"
    end

    test "it renders the pixel in the correct location on a matrix" do
      Neopixel.set_pixel({6, 3}, {255, 0, 128, 64})
      assert_receive "Called set_pixel(x: 6, y: 3, color: 0x40ff0080)"

      Neopixel.render()
      assert_receive "Called render()"
      assert_receive "  [1][22]: 0x40ff0080"
    end

  end

  describe "Nerves.Neopixel.fill" do
    setup [:with_neopixel_stick_and_unicorn_phat]

    test "it fills the correct pixels in multiple channels" do
      Neopixel.fill({2, 0}, 2, 3, {255, 0, 128})
      assert_receive "Called fill(x: 2, y: 0, width: 2, height: 3, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 2, y: 0, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 3, y: 0, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 2, y: 1, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 3, y: 1, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 2, y: 2, color: 0x00ff0080)"
      assert_receive "Called set_pixel(x: 3, y: 2, color: 0x00ff0080)"

      Neopixel.render()
      assert_receive "Called render()"
      assert_receive "  [0][1]: 0x00000000" # <- Should not fill outside the specified bounds
      assert_receive "  [0][2]: 0x00ff0080"
      assert_receive "  [0][3]: 0x00ff0080"
      assert_receive "  [0][4]: 0x00000000" # <- Should not fill outside the specified bounds
      assert_receive "  [1][1]: 0x00000000" # <- Should not fill outside the specified bounds
      assert_receive "  [1][2]: 0x00ff0080"
      assert_receive "  [1][3]: 0x00ff0080"
      assert_receive "  [1][4]: 0x00000000" # <- Should not fill outside the specified bounds
      assert_receive "  [1][9]: 0x00000000" # <- Should not fill outside the specified bounds
      assert_receive "  [1][10]: 0x00ff0080"
      assert_receive "  [1][11]: 0x00ff0080"
      assert_receive "  [1][12]: 0x00000000" # <- Should not fill outside the specified bounds
    end

    test "works with RGB or RGBW colors" do
      Neopixel.fill({2, 0}, 2, 3, {255, 0, 128})
      assert_receive "Called fill(x: 2, y: 0, width: 2, height: 3, color: 0x00ff0080)"

      Neopixel.fill({2, 0}, 2, 3, {255, 0, 128, 64})
      assert_receive "Called fill(x: 2, y: 0, width: 2, height: 3, color: 0x40ff0080)"

    end

  end

  defp flush(type \\ :silent, opts \\ [])
  defp flush(:silent, opts) do
    receive do
      _msg -> flush(:silent, opts)
    after
      0 -> :ok
    end
  end
  defp flush(:inspect, opts) do
    receive do
      msg ->
        IO.inspect(msg, opts)
        flush(:inspect, opts)
    after
      0 -> :ok
    end
  end

  defp neopixel_stick_and_unicorn_phat_config do
    [
      canvas: {8, 5},
      channels: [:channel1, :channel2],
      channel1: [
        pin: 13,
        arrangement: [
          %{
            type: :strip,
            origin: {0, 0},
            count: 8,
            direction: :right
          }
        ]
      ],
      channel2: [
        pin: 18,
        arrangement: [
          %{
            type: :matrix,
            origin: {0, 1},
            count: {8, 4},
            direction: {:right, :down},
            progressive: true
          }
        ]
      ]
    ]
  end
end
