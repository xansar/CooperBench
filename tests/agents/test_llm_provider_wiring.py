"""Tests for provider-aware mini agent wiring."""

from unittest.mock import MagicMock, mock_open, patch

from cooperbench.agents.mini_swe_agent.adapter import MiniSweAgentRunner
from cooperbench.agents.mini_swe_agent_v2.adapter import MiniSweAgentV2Runner


def test_mini_swe_agent_uses_resolved_vllm_config():
    env = MagicMock()
    env.execute.return_value = {"output": "base\n"}

    with patch("cooperbench.agents.mini_swe_agent.adapter.get_config_path", return_value="mini.yaml"):
        with patch("builtins.open", mock_open(read_data="agent: {}")):
            with patch(
                "cooperbench.agents.mini_swe_agent.adapter.yaml.safe_load",
                return_value={"agent": {}, "model": {"model_kwargs": {"drop_params": True}}},
            ):
                with patch("cooperbench.agents.mini_swe_agent.adapter.ModalEnvironment", return_value=env):
                    with patch("cooperbench.agents.mini_swe_agent.adapter.LitellmModel") as mock_model:
                        with patch("cooperbench.agents.mini_swe_agent.adapter.DefaultAgent") as mock_agent:
                            mock_agent.return_value.run.return_value = ("Submitted", None)
                            runner = MiniSweAgentRunner()
                            runner.run(
                                task="task",
                                image="image",
                                model_name="qwen2.5-coder",
                                config={
                                    "llm": {
                                        "provider": "vllm",
                                        "endpoint": "http://localhost:8000/v1",
                                        "model": "qwen2.5-coder",
                                    }
                                },
                            )

    _, kwargs = mock_model.call_args
    assert kwargs["model_name"] == "hosted_vllm/qwen2.5-coder"
    assert kwargs["model_kwargs"]["api_base"] == "http://localhost:8000/v1"


def test_mini_swe_agent_v2_uses_resolved_vllm_config():
    env = MagicMock()
    env.execute.return_value = {"output": "base\n"}

    with patch("cooperbench.agents.mini_swe_agent_v2.adapter.get_config_path", return_value="mini.yaml"):
        with patch("builtins.open", mock_open(read_data="agent: {}")):
            with patch(
                "cooperbench.agents.mini_swe_agent_v2.adapter.yaml.safe_load",
                return_value={"agent": {}, "model": {"model_kwargs": {"drop_params": True}}},
            ):
                with patch(
                    "cooperbench.agents.mini_swe_agent_v2.environments.modal.ModalEnvironment",
                    return_value=env,
                ):
                    with patch("cooperbench.agents.mini_swe_agent_v2.adapter.LitellmModel") as mock_model:
                        with patch("cooperbench.agents.mini_swe_agent_v2.adapter.DefaultAgent") as mock_agent:
                            mock_agent.return_value.run.return_value = {"exit_status": "Submitted"}
                            runner = MiniSweAgentV2Runner()
                            runner.run(
                                task="task",
                                image="image",
                                model_name="qwen2.5-coder",
                                config={
                                    "llm": {
                                        "provider": "vllm",
                                        "endpoint": "http://localhost:8000/v1",
                                        "model": "qwen2.5-coder",
                                    }
                                },
                            )

    _, kwargs = mock_model.call_args
    assert kwargs["model_name"] == "hosted_vllm/qwen2.5-coder"
    assert kwargs["model_kwargs"]["api_base"] == "http://localhost:8000/v1"
