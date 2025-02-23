defmodule WandaWeb.ExecutionView do
  use WandaWeb, :view

  alias WandaWeb.ExecutionView

  alias Wanda.Executions.Execution

  def render("index.json", %{executions: executions, total_count: total_count}) do
    %{
      items: render_many(executions, ExecutionView, "execution.json"),
      total_count: total_count
    }
  end

  def render("show.json", %{execution: execution}) do
    render_one(execution, ExecutionView, "execution.json")
  end

  def render("execution.json", %{
        execution: %Execution{
          execution_id: execution_id,
          group_id: group_id,
          status: status,
          result: result,
          targets: targets,
          started_at: started_at,
          completed_at: completed_at
        }
      }) do
    %{
      check_results: map_check_results(status, result),
      status: status,
      started_at: started_at,
      completed_at: completed_at,
      execution_id: execution_id,
      group_id: group_id,
      result: map_result(status, result),
      targets: targets,
      critical_count: count_results(status, result, "critical"),
      warning_count: count_results(status, result, "warning"),
      passing_count: count_results(status, result, "passing"),
      timeout: map_timeout(status, result)
    }
  end

  def render("start.json", %{
        accepted_execution: %{
          execution_id: execution_id,
          group_id: group_id
        }
      }) do
    %{
      execution_id: execution_id,
      group_id: group_id
    }
  end

  defp map_result(:running, _), do: nil
  defp map_result(:completed, %{"result" => result}), do: result

  defp map_timeout(:running, _), do: nil
  defp map_timeout(:completed, %{"timeout" => timeout}), do: timeout

  defp map_check_results(:running, _), do: nil
  defp map_check_results(:completed, %{"check_results" => check_results}), do: check_results

  defp count_results(:running, _, _), do: nil

  defp count_results(:completed, %{"check_results" => check_results}, severity),
    do: Enum.count(check_results, &(&1["result"] == severity))
end
