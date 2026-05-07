"""Mini-SWE-Agent adapter for CooperBench.

This adapter wraps the mini-swe-agent framework to conform to the
AgentRunner interface used by CooperBench.
"""

from pathlib import Path
from typing import TYPE_CHECKING

import yaml
from jinja2 import StrictUndefined, Template

from cooperbench.agents import AgentResult
from cooperbench.llm_config import resolve_llm_config

if TYPE_CHECKING:
    from cooperbench.agents.mini_swe_agent.environments.docker import DockerEnvironment
from cooperbench.agents.mini_swe_agent.agents.default import AgentConfig, DefaultAgent
from cooperbench.agents.mini_swe_agent.config import get_config_path
from cooperbench.agents.mini_swe_agent.connectors import GitConnector
from cooperbench.agents.mini_swe_agent.connectors.messaging import MessagingConnector
from cooperbench.agents.mini_swe_agent.environments.modal import ModalEnvironment
from cooperbench.agents.mini_swe_agent.models.litellm_model import LitellmModel
from cooperbench.agents.registry import register


@register("mini_swe_agent")
class MiniSweAgentRunner:
    """Adapter for mini-swe-agent framework."""

    def run(
        self,
        task: str,
        image: str,
        *,
        agent_id: str = "agent",
        model_name: str = "gpt-4o",
        agents: list[str] | None = None,
        comm_url: str | None = None,
        git_server_url: str | None = None,
        git_enabled: bool = False,
        messaging_enabled: bool = True,
        config: dict | None = None,
        agent_config: str | None = None,
        log_dir: str | None = None,
    ) -> AgentResult:
        """Run mini-swe-agent on a task.

        Args:
            task: The task description
            image: Docker image with the codebase
            agent_id: Unique identifier for this agent
            model_name: LLM model to use
            agents: List of all agent IDs (for collaboration)
            comm_url: Redis URL for inter-agent messaging
            git_server_url: Git server URL for code sharing
            git_enabled: Whether git collaboration is enabled
            messaging_enabled: Whether messaging is enabled
            config: Agent configuration (loaded from mini.yaml if not provided)

        Returns:
            AgentResult with status, patch, cost, steps, messages
        """
        # Always load default config, then merge with any overrides
        config_path = get_config_path("mini")
        with open(config_path) as f:
            default_config = yaml.safe_load(f)

        # Merge passed config overrides into default config
        if config is not None:
            default_config.update(config)

        agent_cfg = default_config.get("agent", {})
        model_cfg = default_config.get("model", {})
        backend = default_config.get("backend", "modal")
        llm_cfg = default_config.get("llm", {})

        # Create sandbox environment based on backend
        if backend == "docker":
            # Lazy import to avoid requiring docker package when not used
            from cooperbench.agents.mini_swe_agent.environments.docker import DockerEnvironment

            env_kwargs = {
                "image": image,
                "cwd": "/workspace/repo",
                "timeout": 3600,
            }
            # Join git network if provided
            if config and config.get("git_network"):
                env_kwargs["network"] = config["git_network"]
            env = DockerEnvironment(**env_kwargs)
        elif backend == "gcp":
            # Lazy import to avoid requiring google-cloud-compute package when not used
            from cooperbench.agents.mini_swe_agent.environments.gcp import GCPEnvironment

            env_kwargs = {
                "image": image,
                "cwd": "/workspace/repo",
                "timeout": 3600,
            }
            # GCP-specific config
            if config:
                if config.get("project_id"):
                    env_kwargs["project_id"] = config["project_id"]
                if config.get("zone"):
                    env_kwargs["zone"] = config["zone"]
                if config.get("machine_type"):
                    env_kwargs["machine_type"] = config["machine_type"]
                if config.get("git_network"):
                    env_kwargs["network"] = config["git_network"]
                if config.get("vm_image_family"):
                    env_kwargs["vm_image_family"] = config["vm_image_family"]
            env = GCPEnvironment(**env_kwargs)
        else:
            env = ModalEnvironment(
                image=image,
                cwd="/workspace/repo",
                timeout=3600,
            )

        # Capture base commit for patch generation
        base_commit_result = env.execute("git rev-parse HEAD", timeout=10)
        base_commit = base_commit_result.get("output", "").strip()

        # Create LLM model
        resolved_llm = resolve_llm_config(
            model=llm_cfg.get("model", model_name),
            provider=llm_cfg.get("provider"),
            endpoint=llm_cfg.get("endpoint"),
            api_version=llm_cfg.get("api_version"),
        )
        merged_model_cfg = dict(model_cfg)
        merged_model_cfg["model_kwargs"] = {
            **model_cfg.get("model_kwargs", {}),
            **resolved_llm.model_kwargs,
        }
        model = LitellmModel(model_name=resolved_llm.model_name, **merged_model_cfg)

        # Setup messaging connector if enabled
        comm = None
        if messaging_enabled and comm_url and agents and len(agents) > 1:
            comm = MessagingConnector(agent_id=agent_id, agents=agents, url=comm_url)

        # Setup git connector if enabled
        if git_enabled and git_server_url and agents:
            git_connector = GitConnector(
                agent_id=agent_id,
                agents=agents,
                server_url=git_server_url,
            )
            git_connector.setup(env)

        # Create agent with template variables for collaboration
        extra_vars = {
            "agent_id": agent_id if (agents and len(agents) > 1) else None,
            "agents": agents if agents else [],
            "git_enabled": git_enabled,
            "messaging_enabled": messaging_enabled,
        }
        self._append_coop_protocol(
            agent_cfg=agent_cfg,
            protocol_path=default_config.get("coop_protocol_path"),
            task=task,
            env=env,
            model=model,
            extra_vars=extra_vars,
        )

        agent = DefaultAgent(
            model=model,
            env=env,
            comm=comm,
            agent_id=agent_id,
            **agent_cfg,
        )
        agent.extra_template_vars.update(extra_vars)

        # Run agent
        error_msg = None
        try:
            status, _ = agent.run(task=task)
        except Exception as e:
            status = "Error"
            error_msg = str(e)

        # Extract patch (committed + uncommitted changes)
        patch = self._get_patch(env, base_commit)

        # Cleanup
        env.cleanup()

        return AgentResult(
            status=status,
            patch=patch,
            cost=model.cost,
            steps=model.n_calls,
            messages=agent.messages,
            error=error_msg,
        )

    def _append_coop_protocol(
        self,
        *,
        agent_cfg: dict,
        protocol_path: str | None,
        task: str,
        env: "ModalEnvironment | DockerEnvironment",
        model: LitellmModel,
        extra_vars: dict,
    ) -> None:
        """Append a rendered cooperation protocol block to mini-swe-agent's system template."""
        if not protocol_path:
            return

        path = Path(protocol_path)
        if not path.exists():
            raise FileNotFoundError(f"Cooperation protocol file not found: {protocol_path}")

        protocol_template = path.read_text()
        if protocol_template == "":
            return

        config_class = agent_cfg.get("config_class", AgentConfig)
        config_kwargs = {key: value for key, value in agent_cfg.items() if key != "config_class"}
        template_vars = (
            config_class(**config_kwargs).model_dump()
            | env.get_template_vars()
            | model.get_template_vars()
            | {"task": task, **extra_vars}
        )
        rendered_protocol = Template(protocol_template, undefined=StrictUndefined).render(**template_vars)
        agent_cfg["system_template"] = (
            f"{agent_cfg['system_template']}\n\n"
            f"<cooperation_protocol>\n{rendered_protocol}\n</cooperation_protocol>"
        )

    def _get_patch(self, env: "ModalEnvironment | DockerEnvironment", base_commit: str) -> str:
        """Extract git diff from base commit to current working tree state."""
        try:
            # Single diff from base commit to working tree (includes both
            # committed and uncommitted changes)
            result = env.execute(f"git diff {base_commit}", timeout=30)
            return result.get("output", "").strip()
        except Exception:
            return ""
