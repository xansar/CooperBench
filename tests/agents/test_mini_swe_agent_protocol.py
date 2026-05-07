"""Tests for mini_swe_agent cooperation protocol prompt injection."""

from unittest.mock import MagicMock, mock_open, patch

import pytest

from cooperbench.agents.mini_swe_agent.adapter import MiniSweAgentRunner


def _agent_config(system_template: str = "base system") -> dict:
    return {
        "agent": {
            "system_template": system_template,
            "instance_template": "instance {{ task }}",
            "timeout_template": "timeout",
            "format_error_template": "format error",
            "action_observation_template": "observed {{ output }}",
        },
        "model": {},
    }


def _run_with_mocks(config: dict | None = None, default_config: dict | None = None, **kwargs):
    env = MagicMock()
    env.execute.return_value = {"output": "base\n"}
    env.get_template_vars.return_value = {"cwd": "/workspace/repo", "system_info": "linux"}

    model = MagicMock()
    model.cost = 0
    model.n_calls = 0
    model.get_template_vars.return_value = {"model_name": "resolved-model"}

    with patch("cooperbench.agents.mini_swe_agent.adapter.get_config_path", return_value="mini.yaml"):
        with patch("builtins.open", mock_open(read_data="agent: {}")):
            with patch(
                "cooperbench.agents.mini_swe_agent.adapter.yaml.safe_load",
                return_value=default_config or _agent_config(),
            ):
                with patch("cooperbench.agents.mini_swe_agent.adapter.ModalEnvironment", return_value=env):
                    with patch("cooperbench.agents.mini_swe_agent.adapter.LitellmModel", return_value=model):
                        with patch("cooperbench.agents.mini_swe_agent.adapter.DefaultAgent") as mock_agent:
                            mock_agent.return_value.extra_template_vars = {}
                            mock_agent.return_value.run.return_value = ("Submitted", None)
                            mock_agent.return_value.messages = []
                            runner = MiniSweAgentRunner()
                            result = runner.run(
                                task="task body",
                                image="image",
                                config=config,
                                **kwargs,
                            )
    return result, mock_agent


def test_coop_protocol_none_leaves_system_template_unchanged():
    _, mock_agent = _run_with_mocks(config={"coop_protocol_path": None})

    _, kwargs = mock_agent.call_args
    assert kwargs["system_template"] == "base system"


def test_coop_protocol_appends_rendered_block(tmp_path):
    protocol = tmp_path / "protocol.txt"
    protocol.write_text("coordinate before submitting")

    _, mock_agent = _run_with_mocks(config={"coop_protocol_path": str(protocol)})

    _, kwargs = mock_agent.call_args
    assert kwargs["system_template"] == (
        "base system\n\n"
        "<cooperation_protocol>\ncoordinate before submitting\n</cooperation_protocol>"
    )


def test_coop_protocol_renders_jinja_context(tmp_path):
    protocol = tmp_path / "protocol.txt"
    protocol.write_text("id={{ agent_id }} peers={{ agents|join(',') }} git={{ git_enabled }} model={{ model_name }}")

    _, mock_agent = _run_with_mocks(
        config={"coop_protocol_path": str(protocol)},
        agent_id="agent1",
        agents=["agent1", "agent2"],
        git_enabled=True,
    )

    _, kwargs = mock_agent.call_args
    assert "id=agent1" in kwargs["system_template"]
    assert "peers=agent1,agent2" in kwargs["system_template"]
    assert "git=True" in kwargs["system_template"]
    assert "model=resolved-model" in kwargs["system_template"]


def test_coop_protocol_missing_file_fails_fast(tmp_path):
    missing = tmp_path / "missing.txt"

    with pytest.raises(FileNotFoundError, match="Cooperation protocol file not found"):
        _run_with_mocks(config={"coop_protocol_path": str(missing)})
