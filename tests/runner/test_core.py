"""Unit tests for cooperbench.runner.core module."""

import json
from unittest.mock import patch

import pytest

from cooperbench.runner import run


class TestRunConfig:
    """Tests for run configuration and validation."""

    def test_run_requires_name(self):
        """Test that run requires a name parameter."""
        with pytest.raises(TypeError):
            run()  # type: ignore

    def test_run_validates_setting(self):
        """Test that invalid settings are handled."""
        # This should not crash, just find no tasks
        with patch("cooperbench.runner.core.discover_tasks", return_value=[]):
            run(run_name="test", setting="coop")
            run(run_name="test", setting="solo")

    def test_run_handles_no_tasks(self):
        """Test that run handles case with no tasks."""
        with patch("cooperbench.runner.core.discover_tasks", return_value=[]):
            # Should not raise
            run(run_name="test-empty", repo="nonexistent")

    def test_coop_protocol_rejects_non_mini_agent(self):
        """Protocol prompt is intentionally scoped to mini_swe_agent."""
        with pytest.raises(ValueError, match="only supported with --agent mini_swe_agent"):
            run(run_name="test", agent="swe_agent", coop_protocol_path="protocol.txt")


class TestRunOutputStructure:
    """Tests for runner output directory structure."""

    def test_output_directory_format(self, tmp_path):
        """Test that output follows expected structure."""
        # Expected: logs/{run_name}/{setting}/{repo}/{task_id}/{features}/
        run_name = "test-run"
        setting = "coop"
        repo = "test_repo"
        task_id = 123
        features = "f1_f2"

        expected_path = tmp_path / "logs" / run_name / setting / repo / str(task_id) / features
        expected_path.mkdir(parents=True)

        # Verify structure is creatable
        assert expected_path.exists()
        assert expected_path.is_dir()

    def test_result_json_schema(self, tmp_path):
        """Test that result.json has expected schema."""
        result = {
            "run_name": "test",
            "repo": "test_repo",
            "task_id": 123,
            "features": [1, 2],
            "setting": "coop",
            "model": "gpt-4o",
            "status": "completed",
            "started_at": "2026-01-31T12:00:00",
            "ended_at": "2026-01-31T12:05:00",
            "duration_seconds": 300,
            "total_cost": 0.05,
        }

        result_file = tmp_path / "result.json"
        result_file.write_text(json.dumps(result))

        loaded = json.loads(result_file.read_text())
        assert "run_name" in loaded
        assert "setting" in loaded
        assert "duration_seconds" in loaded
        assert "total_cost" in loaded

    def test_config_json_schema(self, tmp_path):
        """Test that config.json has expected schema."""
        config = {
            "run_name": "test",
            "agent_framework": "mini_swe_agent",
            "model": "gemini/gemini-3-flash-preview",
            "setting": "coop",
            "concurrency": 20,
            "total_tasks": 10,
            "started_at": "2026-01-31T12:00:00",
        }

        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config))

        loaded = json.loads(config_file.read_text())
        assert "run_name" in loaded
        assert "agent_framework" in loaded
        assert "model" in loaded
        assert "setting" in loaded


class TestAutoEvalBackend:
    """Tests for auto-eval backend inheritance."""

    def test_single_task_auto_eval_uses_run_backend(self, tmp_path, monkeypatch):
        """Single-task auto-eval should inherit the run backend."""
        monkeypatch.chdir(tmp_path)

        task = {"repo": "llama_index_task", "task_id": 17244, "features": [1, 2]}
        result = {
            "result": {"status": "Submitted", "cost": 0, "steps": 0, "patch": ""},
            "total_cost": 0,
            "duration": 0,
            "log_dir": str(tmp_path / "logs" / "test-run" / "solo" / "llama_index_task" / "17244" / "f1_f2"),
        }

        with patch("cooperbench.runner.core.discover_tasks", return_value=[task]):
            with patch("cooperbench.runner.core.execute_solo", return_value=result):
                with patch("cooperbench.runner.core._print_single_result"):
                    with patch("cooperbench.runner.core._save_summary"):
                        with patch("cooperbench.runner.core._print_summary"):
                            with patch(
                                "cooperbench.utils.get_run_totals",
                                return_value={"total_cost": 0, "wall_time": 0, "run_time": 0},
                            ):
                                with patch(
                                    "cooperbench.eval.evaluate._evaluate_single",
                                    return_value={"both_passed": True},
                                ) as mock_eval:
                                    run(
                                        run_name="test-run",
                                        setting="solo",
                                        backend="docker",
                                        auto_eval=True,
                                    )

        _, kwargs = mock_eval.call_args
        assert kwargs["backend"] == "docker"

    def test_multi_task_auto_eval_uses_run_backend(self, tmp_path, monkeypatch):
        """Multi-task auto-eval should pass through the run backend."""
        monkeypatch.chdir(tmp_path)

        tasks = [
            {"repo": "llama_index_task", "task_id": 17244, "features": [1, 2]},
            {"repo": "llama_index_task", "task_id": 17244, "features": [1, 3]},
        ]
        results = [
            {
                "total_cost": 0,
                "log_dir": str(tmp_path / "logs" / "test-run" / "solo" / "llama_index_task" / "17244" / "f1_f2"),
            },
            {
                "total_cost": 0,
                "log_dir": str(tmp_path / "logs" / "test-run" / "solo" / "llama_index_task" / "17244" / "f1_f3"),
            },
        ]

        with patch("cooperbench.runner.core.discover_tasks", return_value=tasks):
            with patch("cooperbench.runner.core.execute_solo", side_effect=results):
                with patch("cooperbench.runner.core._save_summary"):
                    with patch("cooperbench.runner.core._print_summary"):
                        with patch(
                            "cooperbench.utils.get_run_totals",
                            return_value={"total_cost": 0, "wall_time": 0, "run_time": 0},
                        ):
                            with patch(
                                "cooperbench.eval.evaluate._evaluate_single",
                                return_value={"both_passed": True},
                            ) as mock_eval:
                                run(
                                    run_name="test-run",
                                    setting="solo",
                                    backend="docker",
                                    auto_eval=True,
                                    concurrency=1,
                                    eval_concurrency=1,
                                )

        assert mock_eval.call_count == 2
        for call in mock_eval.call_args_list:
            assert call.kwargs == {}
            assert call.args[2] == "docker"

    def test_auto_eval_disabled_skips_evaluation(self, tmp_path, monkeypatch):
        """Disabling auto-eval should avoid evaluation calls entirely."""
        monkeypatch.chdir(tmp_path)

        task = {"repo": "llama_index_task", "task_id": 17244, "features": [1, 2]}
        result = {
            "result": {"status": "Submitted", "cost": 0, "steps": 0, "patch": ""},
            "total_cost": 0,
            "duration": 0,
            "log_dir": str(tmp_path / "logs" / "test-run" / "solo" / "llama_index_task" / "17244" / "f1_f2"),
        }

        with patch("cooperbench.runner.core.discover_tasks", return_value=[task]):
            with patch("cooperbench.runner.core.execute_solo", return_value=result):
                with patch("cooperbench.runner.core._print_single_result"):
                    with patch("cooperbench.runner.core._save_summary"):
                        with patch("cooperbench.runner.core._print_summary"):
                            with patch(
                                "cooperbench.utils.get_run_totals",
                                return_value={"total_cost": 0, "wall_time": 0, "run_time": 0},
                            ):
                                with patch("cooperbench.eval.evaluate._evaluate_single") as mock_eval:
                                    run(
                                        run_name="test-run",
                                        setting="solo",
                                        backend="docker",
                                        auto_eval=False,
                                    )

        mock_eval.assert_not_called()
