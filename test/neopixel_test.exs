defmodule Nerves.Neopixel.Test do
  use ExUnit.Case
  doctest Nerves.Neopixel

  alias Nerves.Neopixel
  alias Neopixel.{
    Channel,
    Config,
    HAL
  }

  describe "configuration" do
    test "configuring two channels" do
      use Mix.config

      config :nerves_neopixel,
        channels: [:channel1, :channel2]

      config :nerves_neopixel, :channel1,
        pin: 19,
        count: 5

      config :nerves_neopixel, :channel2,
        pin: 18,
        count: 3

      assert Config.load() == %Config{
        channels: [
          %Channel{
            name: :channel1,
            pin: 19,
            arrangement: [
              %Strip{
                count: 4,
                origin: {0, 0},
                rotation: 0,
              },
              %Strip{
                count: 4,
                origin: {3, 1},
                rotation: 180,
              },
              %Strip{
                count: 4,
                origin: {0, 2},
                rotation: 0,
              },
              %Strip{
                count: 4,
                origin: {3, 3},
                rotation: 180,
              },
            ]
          },
          %Channel{
            name: :channel2,
            pin: 18,
            count: 3
          }
        ]
      }
    end
  end

  test "configuring a Neopixel interface" do
    ch0_config = [pin: 18, count: 3]
    ch1_config = [pin: 19, count: 3]
    {:ok, pid} = Neopixel.start_link(ch0_config, ch1_config)
    assert is_pid(pid)
  end

  test "rendering a pixel" do
    ch0_config = [pin: 18, count: 3]
    ch1_config = [pin: 19, count: 3]
    {:ok, pid} = Neopixel.start_link(ch0_config, ch1_config)
    assert is_pid(pid)

    channel = 0
    intensity = 127

    data = [
      {255, 0, 0},
      {0, 255, 0},
      {0, 0, 255}
    ]

    assert Neopixel.render(channel, {intensity, data}) == :ok
  end
end
