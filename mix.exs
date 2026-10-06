defmodule Runtimes.MixProject do
  use Mix.Project

  def project do
    [
      app: :runtimes,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      # Docs
      name: "Runtimes",
      source_url: "https://github.com/marmoos-project/elixir-runtimes",
      homepage_url: "https://github.com/marmoos-project/elixir-runtimes",
      docs: &docs/0
    ]
  end

  def cli do
    [preferred_envs: [docs: :doc]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:doc), do: ["lib", "assets"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:mix]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev, :doc], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      formatters: [Runtimes.Docs.Html, "markdown", "epub"],
      logo: "assets/logo.svg",
      extras: ["README.md"],
      source_ref: "master",
      groups_for_modules: [
        "Mix tasks": ~r/^Mix\.Tasks\./,
        NIF: ~r/^Runtimes\.Packages\.Nif\./,
        Packages: ~r/^Runtimes\.Packages\.Package\./
      ]
    ]
  end
end
