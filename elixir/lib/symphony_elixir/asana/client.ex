defmodule SymphonyElixir.Asana.Client do
  @moduledoc """
  REST client for the Asana API v1.

  Handles all HTTP communication with Asana. Authentication is via a
  Personal Access Token passed as a Bearer token. The project GID and
  API key are read from Symphony's runtime config (set in WORKFLOW.md
  and the ASANA_API_KEY environment variable).

  State in Symphony maps to Sections in Asana. Moving a task to a
  different section is equivalent to updating its state in Linear.
  """

  alias SymphonyElixir.Asana.Task
  alias SymphonyElixir.Config

  @base_url "https://app.asana.com/api/1.0"

  # Fields requested on every task fetch — includes section membership
  # so we can derive the task's current "state" without a second request.
  @task_fields "gid,name,notes,memberships.section.name,memberships.project.gid"

  # ---------------------------------------------------------------------------
  # Tracker behaviour surface
  # ---------------------------------------------------------------------------

  @spec fetch_candidate_issues() :: {:ok, [Task.t()]} | {:error, term()}
  def fetch_candidate_issues do
    settings = Config.settings!()
    fetch_issues_by_states(settings.tracker.active_states)
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [Task.t()]} | {:error, term()}
  def fetch_issues_by_states(state_names) do
    settings = Config.settings!()
    project_gid = settings.tracker.project_slug

    with {:ok, sections} <- fetch_sections(project_gid) do
      matching = Enum.filter(sections, &(&1["name"] in state_names))

      tasks =
        Enum.flat_map(matching, fn section ->
          case tasks_in_section(section["gid"]) do
            {:ok, tasks} -> tasks
            _ -> []
          end
        end)

      {:ok, tasks}
    end
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [map()]} | {:error, term()}
  def fetch_issue_states_by_ids(task_gids) do
    results =
      Enum.map(task_gids, fn gid ->
        case get("/tasks/#{gid}", %{"opt_fields" => @task_fields}) do
          {:ok, %{"data" => raw}} -> Task.from_api(raw)
          _                       -> nil
        end
      end)

    {:ok, Enum.reject(results, &is_nil/1)}
  end

  @spec create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  def create_comment(task_gid, body) do
    case post("/tasks/#{task_gid}/stories", %{"data" => %{"text" => body}}) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Section helpers (used by the adapter for state transitions)
  # ---------------------------------------------------------------------------

  @spec resolve_section_gid(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def resolve_section_gid(project_gid, section_name) do
    with {:ok, sections} <- fetch_sections(project_gid) do
      case Enum.find(sections, &(&1["name"] == section_name)) do
        %{"gid" => gid} -> {:ok, gid}
        nil -> {:error, {:section_not_found, section_name}}
      end
    end
  end

  @spec update_task_section(String.t(), String.t()) :: :ok | {:error, term()}
  def update_task_section(task_gid, section_gid) do
    case post("/sections/#{section_gid}/addTask", %{"data" => %{"task" => task_gid}}) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_sections(String.t()) :: {:ok, [map()]} | {:error, term()}
  def fetch_sections(project_gid) do
    case get("/projects/#{project_gid}/sections", %{"opt_fields" => "gid,name"}) do
      {:ok, %{"data" => sections}} -> {:ok, sections}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp tasks_in_section(section_gid) do
    params = %{
      "opt_fields" => @task_fields,
      # Only return incomplete tasks
      "completed_since" => "now"
    }

    case get("/sections/#{section_gid}/tasks", params) do
      {:ok, %{"data" => tasks}} -> {:ok, Enum.map(tasks, &Task.from_api/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get(path, params \\ %{}) do
    url = @base_url <> path

    case Req.get(url, headers: auth_headers(), params: params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post(path, body) do
    url = @base_url <> path

    case Req.post(url, headers: auth_headers(), json: body) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_headers do
    [{"authorization", "Bearer #{Config.settings!().tracker.api_key}"}]
  end
end
