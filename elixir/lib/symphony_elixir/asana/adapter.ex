defmodule SymphonyElixir.Asana.Adapter do
  @moduledoc """
  Asana-backed tracker adapter for Symphony.

  Implements the SymphonyElixir.Tracker behaviour using Asana projects
  and sections in place of Linear projects and workflow states.

  ## Section → State mapping

  Symphony moves issues through named states (e.g. "Todo", "In Progress",
  "Human Review", "Done"). In Asana, these correspond directly to sections
  within your project. Before running Symphony, ensure your Asana project
  has sections that match the state names configured in WORKFLOW.md:

      tracker:
        kind: asana
        project_slug: "1234567890123456"   # Asana project GID
        active_states: ["Todo", "Ready for Dev"]
        terminal_states: ["Done", "Cancelled"]

  Symphony will pick up tasks in `active_states` sections and stop
  working on tasks that move to `terminal_states` sections.

  ## Authentication

  Set the ASANA_API_KEY environment variable to a Personal Access Token
  generated at https://app.asana.com/0/my-apps.
  """

  @behaviour SymphonyElixir.Tracker

  alias SymphonyElixir.Asana.Client
  alias SymphonyElixir.Config

  @impl true
  def fetch_candidate_issues, do: client().fetch_candidate_issues()

  @impl true
  def fetch_issues_by_states(states), do: client().fetch_issues_by_states(states)

  @impl true
  def fetch_issue_states_by_ids(task_gids), do: client().fetch_issue_states_by_ids(task_gids)

  @impl true
  def create_comment(task_gid, body), do: client().create_comment(task_gid, body)

  @impl true
  def update_issue_state(task_gid, section_name) do
    project_gid = Config.settings!().tracker.project_slug

    with {:ok, section_gid} <- client().resolve_section_gid(project_gid, section_name) do
      client().update_task_section(task_gid, section_gid)
    end
  end

  # Allows the client module to be swapped out in tests via application config:
  # config :symphony_elixir, :asana_client_module, MyMockClient
  defp client do
    Application.get_env(:symphony_elixir, :asana_client_module, Client)
  end
end
