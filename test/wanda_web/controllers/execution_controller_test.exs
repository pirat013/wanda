defmodule WandaWeb.ExecutionControllerTest do
  use WandaWeb.ConnCase, async: true

  import Mox
  import OpenApiSpex.TestAssertions
  import Wanda.Factory

  alias WandaWeb.ApiSpec

  alias Wanda.Executions.Target

  setup :verify_on_exit!

  describe "list executions" do
    test "should return a list of executions", %{conn: conn} do
      insert_list(5, :execution)

      json =
        conn
        |> get("/api/checks/executions")
        |> json_response(200)

      api_spec = ApiSpec.spec()
      assert_schema(json, "ListExecutionsResponse", api_spec)
    end

    test "should return a 422 status code if an invalid paramaters is passed", %{conn: conn} do
      conn = get(conn, "/api/checks/executions?limit=invalid")

      assert 422 == conn.status
    end
  end

  describe "get execution" do
    test "should return a running execution", %{conn: conn} do
      %{execution_id: execution_id} = insert(:execution)

      json =
        conn
        |> get("/api/checks/executions/#{execution_id}")
        |> json_response(200)

      api_spec = ApiSpec.spec()
      assert_schema(json, "ExecutionResponse", api_spec)
    end

    test "should return a completed execution", %{conn: conn} do
      targets = build_pair(:execution_target)
      check_results = build(:check_results_from_targets, targets: targets)
      result = build(:result, check_results: check_results, result: :passing)

      %{execution_id: execution_id} =
        insert(:execution, status: :completed, completed_at: DateTime.utc_now(), result: result)

      json =
        conn
        |> get("/api/checks/executions/#{execution_id}")
        |> json_response(200)

      api_spec = ApiSpec.spec()
      assert_schema(json, "ExecutionResponse", api_spec)
    end

    test "should return a completed execution with errors", %{conn: conn} do
      checks = ["check_id"]
      [target_1, target_2, target_3] = targets = build_list(3, :execution_target, checks: checks)

      expectation_name = "expectation_with_error"

      expectation_evaluations =
        build_list(1, :expectation_evaluation_error, name: expectation_name)

      agent_check_results = [
        build(:agent_check_result,
          agent_id: target_1.agent_id,
          expectation_evaluations: expectation_evaluations
        ),
        build(:agent_check_error,
          agent_id: target_2.agent_id
        ),
        build(:agent_check_error,
          agent_id: target_3.agent_id,
          facts: nil,
          message: "timeout",
          type: :timeout
        )
      ]

      expectation_results =
        build_list(1, :expectation_result, name: expectation_name, result: false)

      check_results =
        build_list(1, :check_result,
          expectation_results: expectation_results,
          agents_check_results: agent_check_results
        )

      result =
        build(:result,
          check_results: check_results,
          result: :critical,
          timeout: [target_3.agent_id]
        )

      %{execution_id: execution_id} =
        insert(:execution,
          status: :completed,
          completed_at: DateTime.utc_now(),
          targets: targets,
          result: result
        )

      json =
        conn
        |> get("/api/checks/executions/#{execution_id}")
        |> json_response(200)

      api_spec = ApiSpec.spec()
      assert_schema(json, "ExecutionResponse", api_spec)
    end

    test "should return a 404", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, "/api/checks/executions/#{UUID.uuid4()}")
      end)
    end
  end

  describe "get last execution by group id" do
    test "should return the last execution", %{conn: conn} do
      %{group_id: group_id} = 10 |> insert_list(:execution) |> List.last()

      json =
        conn
        |> get("/api/checks/groups/#{group_id}/executions/last")
        |> json_response(200)

      api_spec = ApiSpec.spec()
      assert_schema(json, "ExecutionResponse", api_spec)
    end

    test "should return a 404", %{conn: conn} do
      assert_error_sent(404, fn ->
        get(conn, "/api/checks/groups/#{UUID.uuid4()}/executions/last")
      end)
    end
  end

  describe "start execution" do
    test "should start an execution", %{conn: conn} do
      execution_id = UUID.uuid4()
      group_id = UUID.uuid4()

      targets = [
        %{
          "agent_id" => agent_id = UUID.uuid4(),
          "checks" => checks = ["expect_check"]
        }
      ]

      env = build(:env)

      expect(Wanda.Executions.ServerMock, :start_execution, fn ^execution_id,
                                                               ^group_id,
                                                               [
                                                                 %Target{
                                                                   agent_id: ^agent_id,
                                                                   checks: ^checks
                                                                 }
                                                               ],
                                                               ^env ->
        :ok
      end)

      json =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/checks/executions/start", %{
          "execution_id" => execution_id,
          "group_id" => group_id,
          "targets" => targets,
          "env" => env
        })
        |> json_response(202)

      api_spec = ApiSpec.spec()
      assert_schema(json, "AcceptedExecutionResponse", api_spec)
    end

    test "should return an error when the start execution operation fails", %{
      conn: conn
    } do
      execution_id = UUID.uuid4()
      group_id = UUID.uuid4()

      targets = [
        %{
          agent_id: agent_id = UUID.uuid4(),
          checks: checks = ["expect_check"]
        }
      ]

      env = build(:env)

      expect(Wanda.Executions.ServerMock, :start_execution, fn ^execution_id,
                                                               ^group_id,
                                                               [
                                                                 %Target{
                                                                   agent_id: ^agent_id,
                                                                   checks: ^checks
                                                                 }
                                                               ],
                                                               ^env ->
        {:error, :already_running}
      end)

      json =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/checks/executions/start", %{
          "execution_id" => execution_id,
          "group_id" => group_id,
          "targets" => targets,
          "env" => env
        })
        |> json_response(422)

      assert %{"error" => %{"detail" => "already_running"}} = json
    end

    test "should return an error on validation failure", %{conn: conn} do
      json =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/checks/executions/start",
          %{
            "group_id" => UUID.uuid4(),
            "targets" => [
              %{
                "agent_id" => UUID.uuid4(),
                "checks" => ["expect_check"]
              }
            ],
            "env" => %{
              "provider" => "azure"
            }
          }
        )
        |> json_response(422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Missing field: execution_id",
                   "source" => %{"pointer" => "/execution_id"},
                   "title" => "Invalid value"
                 }
               ]
             } = json
    end
  end
end
