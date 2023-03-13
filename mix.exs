defmodule BlindLumpyCake.MixProject do
  use Mix.Project

  def project do
    [
      app: :blind_lumpy_cake,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # ++ This needs to be added
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:evision, "~> 0.1"},
    ]
  end

  # This function lets us designate CLI module as the entry point to
  # execution and CLI.main() function is passed the cmd args.
  defp escript do
    [main_module: CLI]
  end
end
