defmodule Nerves.Neopixel.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nerves_neopixel,
      version: "1.0.0-dev",
      description: "Drive WS2812B \"NeoPixel\" RGB LED strips from a Raspberry Pi using Elixir.",
      elixir: "~> 1.3",
      make_clean: ["clean"],
      compilers: compilers(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application() do
    [mod: {Nerves.Neopixel.Application, []},
     extra_applications: [:logger]]
  end

  defp deps do
    [{:elixir_make, "~> 0.4", runtime: false}]
  end

  defp compilers(:test), do: Mix.compilers()
  defp compilers(_), do: [:elixir_make | Mix.compilers()]

  defp package do
    [
      files: [
        "lib",
        "src/*.[ch]",
        "src/rpi_ws281x/*.[ch]",
        "config",
        "mix.exs",
        "README*",
        "LICENSE*",
        "Makefile"
      ],
      maintainers: ["Greg Mefford"],
      licenses: ["MIT", "BSD 2-Clause"],
      links: %{"GitHub" => "https://github.com/GregMefford/nerves_neopixel"}
    ]
  end
end
