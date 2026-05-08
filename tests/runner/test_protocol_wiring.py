"""Tests for cooperation protocol path runner wiring."""

from unittest.mock import MagicMock, patch

from cooperbench.agents import AgentResult
from cooperbench.runner.solo import _spawn_solo_agent


def test_spawn_solo_agent_adds_coop_protocol_path_to_config(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    feature_dir = tmp_path / "dataset" / "test_repo" / "task1" / "feature1"
    feature_dir.mkdir(parents=True)
    (feature_dir / "feature.md").write_text("implement feature")

    runner = MagicMock()
    runner.run.return_value = AgentResult(status="Submitted", patch="", cost=0, steps=0)

    with patch("cooperbench.runner.solo.get_image_name", return_value="test-image"):
        with patch("cooperbench.runner.solo.get_runner", return_value=runner):
            _spawn_solo_agent(
                repo_name="test_repo",
                task_id=1,
                features=[1],
                agent_name="mini_swe_agent_v2",
                model_name="gpt-4o",
                coop_protocol_path="protocol.txt",
            )

    _, kwargs = runner.run.call_args
    assert kwargs["config"]["coop_protocol_path"] == "protocol.txt"
