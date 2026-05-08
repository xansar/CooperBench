"""Tests for mini_swe_agent_v2 Docker environment failure handling."""

from types import SimpleNamespace
from unittest.mock import patch

import pytest

from cooperbench.agents.mini_swe_agent_v2.environments.docker import (
    DockerEnvironment,
    DockerEnvironmentConfig,
)


def make_environment() -> DockerEnvironment:
    env = object.__new__(DockerEnvironment)
    env.container_id = "deadbeef"
    env.config = DockerEnvironmentConfig(image="test-image", cwd="/workspace/repo")
    return env


def test_execute_raises_when_container_has_disappeared():
    env = make_environment()

    completed = SimpleNamespace(
        stdout="Error response from daemon: No such container: deadbeef\n",
        returncode=1,
    )
    with patch("cooperbench.agents.mini_swe_agent_v2.environments.docker.subprocess.run", return_value=completed):
        with pytest.raises(RuntimeError, match="Docker container is unavailable"):
            env.execute({"command": "git diff HEAD"})

    assert env.container_id is None


def test_start_container_overrides_task_image_entrypoint():
    completed = SimpleNamespace(stdout="container123\n", returncode=0)

    with patch("cooperbench.agents.mini_swe_agent_v2.environments.docker.subprocess.run", return_value=completed) as run:
        env = DockerEnvironment(image="task-image", cwd="/workspace/repo", network="cooperbench-git-test")

    cmd = run.call_args.args[0]
    image_index = cmd.index("task-image")

    assert env.container_id == "container123"
    assert cmd[cmd.index("--entrypoint") + 1] == "/bin/bash"
    assert cmd[image_index + 1] == "-c"
    assert cmd[image_index + 2] == "sleep 2h"
    assert cmd.index("--network") < image_index
    assert cmd[cmd.index("--network") + 1] == "cooperbench-git-test"


def test_cleanup_is_idempotent():
    env = make_environment()

    with patch("cooperbench.agents.mini_swe_agent_v2.environments.docker.subprocess.Popen") as popen:
        env.cleanup()
        env.cleanup()

    assert popen.call_count == 1
    assert env.container_id is None
