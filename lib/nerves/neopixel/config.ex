defmodule Nerves.Neopixel.Config do
  alias Nerves.Neopixel.{
    Canvas,
    Channel,
    Config
  }

  defstruct [
    :canvas,
    :channels
  ]

  def load(nil), do: load(Application.get_all_env(:nerves_neopixel))
  def load(config) do
    canvas =
      config
      |> Keyword.get(:canvas)
      |> Canvas.load_config()

    channels =
      config
      |> Keyword.get(:channels)
      |> case do
        nil -> raise "You must configure a list of :channels for :nerves_neopixel"
        channels -> channels
      end
      |> Enum.map(fn name -> load_channel_config(config, name) end)

    %Config{
      canvas: canvas,
      channels: validate_channels(channels),
    }
  end

  defp load_channel_config(config, name) do
    config
    |> Keyword.get(name)
    |> case do
      nil -> raise "Missing configuration for channel #{name}"
      channel_config -> Channel.load_config(channel_config)
    end
  end

  defp validate_channels(channels) do
    pwm_channels = Enum.map(channels, & Channel.pwm_channel/1)
    if (Enum.dedup(pwm_channels) != pwm_channels) do
      raise "Each channel must have a :pin from a different hardware PWM channel"
    end
    channels
  end
end
