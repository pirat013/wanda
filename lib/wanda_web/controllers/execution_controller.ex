defmodule WandaWeb.ExecutionController do
  use WandaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  alias Wanda.Executions
  alias Wanda.Executions.Target

  alias WandaWeb.Schemas.{
    AcceptedExecutionResponse,
    ExecutionResponse,
    ListExecutionsResponse,
    StartExecutionRequest
  }

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  operation :index,
    summary: "List executions",
    parameters: [
      group_id: [
        in: :query,
        description: "Filter by group ID",
        type: %Schema{
          type: :string,
          format: :uuid
        },
        example: "00000000-0000-0000-0000-000000000001"
      ],
      page: [in: :query, description: "Page", type: :integer, example: 3],
      items_per_page: [in: :query, description: "Items per page", type: :integer, example: 20]
    ],
    responses: %{
      200 => {"List executions response", "application/json", ListExecutionsResponse},
      422 => OpenApiSpex.JsonErrorResponse.response()
    }

  operation :show,
    summary: "Get an execution by ID",
    parameters: [
      id: [
        in: :path,
        description: "Execution ID",
        type: %Schema{
          type: :string,
          format: :uuid
        },
        example: "00000000-0000-0000-0000-000000000001"
      ]
    ],
    responses: %{
      200 => {"Execution", "application/json", ExecutionResponse},
      404 => OpenApiSpex.JsonErrorResponse.response()
    }

  operation :last,
    summary: "Get the last execution of a group",
    parameters: [
      id: [
        in: :path,
        description: "Group ID",
        type: %Schema{
          type: :string,
          format: :uuid
        },
        example: "00000000-0000-0000-0000-000000000001"
      ]
    ],
    responses: %{
      200 => {"Execution", "application/json", ExecutionResponse},
      404 => OpenApiSpex.JsonErrorResponse.response()
    }

  operation :start,
    summary: "Start a Checks Execution",
    description: "Start a Checks Execution on the target infrastructure",
    request_body: {"Execution Context", "application/json", StartExecutionRequest},
    responses: %{
      202 => {"Accepted Execution Response", "application/json", AcceptedExecutionResponse},
      422 => OpenApiSpex.JsonErrorResponse.response()
    }

  def index(conn, params) do
    executions = Executions.list_executions(params)
    total_count = Executions.count_executions(params)

    render(conn, executions: executions, total_count: total_count)
  end

  def show(conn, %{id: execution_id}) do
    execution = Executions.get_execution!(execution_id)

    render(conn, execution: execution)
  end

  def last(conn, %{id: group_id}) do
    execution = Executions.get_last_execution_by_group_id!(group_id)

    render(conn, :show, execution: execution)
  end

  def start(
        conn,
        _params
      ) do
    %{
      execution_id: execution_id,
      group_id: group_id,
      targets: targets,
      env: env
    } = Map.get(conn, :body_params)

    case execution_server_impl().start_execution(
           execution_id,
           group_id,
           Target.map_targets(targets),
           env
         ) do
      :ok ->
        conn
        |> put_status(:accepted)
        |> render(
          accepted_execution: %{
            execution_id: execution_id,
            group_id: group_id
          }
        )

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(WandaWeb.ErrorView)
        |> render("422.json", error: reason)
    end
  end

  defp execution_server_impl,
    do: Application.fetch_env!(:wanda, Wanda.Policy)[:execution_server_impl]
end
