defmodule SymphonyElixir.Asana.Task do
  @moduledoc """
  Converts an Asana REST API task response into the Linear.Issue struct that
  Symphony's orchestrator expects. Sections in Asana map to states in Linear.
  """

  alias SymphonyElixir.Linear.Issue

  @spec from_api(map()) :: Issue.t()
  def from_api(%{"gid" => gid} = task) do
    membership = task |> Map.get("memberships", []) |> List.first(%{})

    state = membership |> Map.get("section", %{}) |> Map.get("name")

    project_gid = membership |> Map.get("project", %{}) |> Map.get("gid")

    url =
      if project_gid do
        "https://app.asana.com/0/#{project_gid}/#{gid}"
      end

    %Issue{
      id: gid,
      identifier: gid,
      title: task["name"] || "",
      description: task["notes"] || "",
      state: state,
      url: url
    }
  end
end
