defmodule BambooPepipost.MixProject do
  use Mix.Project

  def project do
    [
      app: :bamboo_pepipost,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bamboo, github: "akash-akya/bamboo"},
      {:hackney, ">= 1.13.0"},
      {:jason, "~> 1.0"}
    ]
  end
end
