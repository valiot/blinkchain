defmodule Nerves.Neopixel.Channel do
  alias Nerves.Neopixel.{
    Channel,
    Matrix,
    Strip
  }

  defstruct [
    pin: 0,
    brightness: 0,
    invert: false,
    type: :ws2811,
    arrangement: nil
  ]

  def load_config(channel_config) do
    if is_nil(pwm_channel(channel_config[:pin])), do: raise "Each channel must specify a PWM-capable I/O :pin"
    %Channel{
      pin: channel_config[:pin],
      arrangement: load_arrangement(channel_config[:arrangement])
    }
  end

  def total_count(%Channel{arrangement: arrangement}) do
    Enum.reduce(arrangement, 0, fn (%Strip{count: count}, acc) -> acc + count end)
  end

  def pwm_channel(%Channel{pin: pin}), do: pwm_channel(pin)
  def pwm_channel(pin) when is_number(pin) and pin in [12, 18, 40, 52], do: 1
  def pwm_channel(pin) when is_number(pin) and pin in [13, 19, 41, 45, 53], do: 2
  def pwm_channel(_), do: nil

  defp load_arrangement(sections) when is_list(sections) do
    sections
    |> Enum.map(&load_section/1)
    |> List.flatten()
  end
  defp load_arrangement(_), do: raise "You must configure the :arrangement of pixels in each channel as a list"

  defp load_section(%{type: :matrix} = matrix_config) do
    matrix_config
    |> Matrix.load_config()
    |> Matrix.to_strip_list()
  end
  defp load_section(%{type: :strip} = strip_config) do
    strip_config
    |> Strip.load_config()
  end

end
