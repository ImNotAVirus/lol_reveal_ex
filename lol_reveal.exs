## Setup
Mix.install([{:httpoison, "~> 2.0"}, {:poison, "~> 5.0"}])

## Code

defmodule LolRevealer.ProcessExplorer do
  @moduledoc """
  TODO
  """

  @spec get_cmdline(String.t()) :: String.t() | nil
  def get_cmdline(proc_name) do
    # Get all processes
    {result, 0} = System.cmd("cmd.exe", ["/c", "wmic path win32_process get name,commandline"])

    cmdline =
      result
      |> String.split("\r\n")
      |> Enum.map(&String.trim/1)
      |> Enum.find(&String.ends_with?(&1, proc_name))

    if not is_nil(cmdline) do
      cmdline |> String.trim_trailing(proc_name) |> String.trim_trailing()
    end
  end
end

defmodule LolRevealer.Endpoint do
  @enforce_keys [:port, :token]
  defstruct @enforce_keys

  @type t :: %__MODULE__{port: 1..25565, token: String.t()}
end

defmodule LolRevealer.LocalEndpoints do
  @enforce_keys [:riot, :client]
  defstruct @enforce_keys

  alias LolRevealer.Endpoint

  @type t :: %__MODULE__{riot: Endpoint.t(), client: Endpoint.t()}
end

defmodule LolRevealer do
  @moduledoc """
  TODO
  """

  alias LolRevealer.ProcessExplorer
  alias LolRevealer.{Endpoint, LocalEndpoints}

  def porofessor_url() do
    cmdline = ProcessExplorer.get_cmdline("LeagueClientUx.exe")
    endpoints = extract_endpoints(cmdline)
    players = make_request("/chat/v5/participants/champ-select", endpoints.riot)["participants"]

    if not Enum.empty?(players) do
      region =
        make_request("/riotclient/get_region_locale", endpoints.client)
        |> Map.fetch!("region")
        |> String.downcase()

      players
      |> Enum.map(&Map.fetch!(&1, "name"))
      |> Enum.join(",")
      |> String.replace(" ", "%20")
      |> then(&"https://porofessor.gg/pregame/#{region}/#{&1}")
      |> IO.puts()
    else
      IO.puts("You're not in champ select :(")
    end
  end

  ## Private function

  defp make_request(path, endpoint_struct) do
    url = "https://127.0.0.1:#{endpoint_struct.port}#{path}"
    headers = [Authorization: "Basic #{endpoint_struct.token}"]
    opts = [hackney: [:insecure]]

    HTTPoison.get!(url, headers, opts)
    |> Map.fetch!(:body)
    |> Poison.decode!()
  end

  defp extract_endpoints(cmdline) do
    %LocalEndpoints{
      riot: make_riot_endpoint(cmdline),
      client: make_client_endpoint(cmdline)
    }
  end

  defp make_riot_endpoint(cmdline) do
    %Endpoint{
      port: extract_port(~r/--riotclient-app-port=(\d+)/, cmdline),
      token: extract_token(~r/--riotclient-auth-token=(\w+)/, cmdline)
    }
  end

  defp make_client_endpoint(cmdline) do
    %Endpoint{
      port: extract_port(~r/--app-port=(\d+)/, cmdline),
      token: extract_token(~r/--remoting-auth-token=(\w+)/, cmdline)
    }
  end

  defp extract_port(regex, cmdline) do
    regex
    |> Regex.run(cmdline, capture: :all_but_first)
    |> Enum.at(0)
    |> String.to_integer()
  end

  defp extract_token(regex, cmdline) do
    regex
    |> Regex.run(cmdline, capture: :all_but_first)
    |> Enum.at(0)
    |> then(&"riot:#{&1}")
    |> Base.encode64()
  end
end

LolRevealer.porofessor_url()
