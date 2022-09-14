defmodule Wanda.Execution.AgentCheckResult do
  @moduledoc """
  Represents the result of a check on a specific agent.
  """

  alias Wanda.Execution.{
    ExpectationEvaluation,
    ExpectationEvaluationError,
    Fact
  }

  @derive Jason.Encoder
  defstruct [
    :agent_id,
    :facts,
    :expectation_evaluations
  ]

  @type t :: %__MODULE__{
          agent_id: String.t(),
          facts: [Fact.t()],
          expectation_evaluations: [ExpectationEvaluation.t() | ExpectationEvaluationError.t()]
        }
end
