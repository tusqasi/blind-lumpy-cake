defmodule CLI do
  def main(args) do
    IO.puts("Hi there")
    pid = spawn(That, :show_video, [nil])
    Process.sleep(10000)
    Process.exit(pid, :ok)
    # args |> parse_args |> process_args
    #
    # receive_command()
  end

  def parse_args(args) do
    {params, _, _} = OptionParser.parse(args, switches: [help: :boolean])
    params
  end

  def process_args(help: true) do
    print_help_message()
  end

  def process_args(_) do
    IO.puts("Welcome to the Matrix Detector")
    print_help_message()
    receive_command()
  end

  @commands %{
    "quit (q)" => "Quits",
    "start" =>
      "Takes the new values " <>
        "Where facing is: north, west, south or east. " <>
        "Format: \"place [X,Y,F]\".",
    "report" => "The Toy config reports about its position",
    "left" => "Rotates the config to the left",
    "right" => "Rotates the config to the right",
    "move" => "Moves the config one position forward"
  }
  # get the list of values to change
  @spec receive_command(list() | nil) :: list()
  defp receive_command(config \\ nil) do
    command =
      IO.gets("> ")
      |> String.trim()
      |> String.downcase()
      |> String.split(" ")

    case command do
      ["run", config] -> spawn(That, :show_video, config)
    end
  end

  defp execute_command(["report"], nil) do
    IO.puts("The config has not been placed yet.")
    receive_command()
  end

  defp execute_command(_unknown, config) do
    IO.puts("\n❌ Invalid command.")
    print_help_message()

    receive_command(config)
  end

  defp print_help_message do
    IO.puts("\nThis projects supports following commands:\n")

    @commands
    |> Enum.map(fn {command, description} -> IO.puts("  #{command} - #{description}") end)

    IO.puts("")
  end
end
