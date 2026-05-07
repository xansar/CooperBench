"""Tests for mini_swe_agent_v2 observation formatting."""

from cooperbench.agents.mini_swe_agent_v2.models.utils.actions_toolcall import format_toolcall_observation_messages


def test_observation_template_allows_missing_exception_info():
    messages = format_toolcall_observation_messages(
        actions=[{"tool_name": "bash", "tool_call_id": "call-1"}],
        outputs=[{"output": "ok", "returncode": 0}],
        observation_template=(
            "{"
            '"returncode": {{ output.returncode }}, '
            '"output": {{ output.output | tojson }}'
            '{% if output.exception_info %}, '
            '"exception_info": {{ output.exception_info | tojson }}'
            "{% endif %}"
            "}"
        ),
    )

    assert messages[0]["content"] == '{"returncode": 0, "output": "ok"}'
    assert messages[0]["extra"]["exception_info"] == ""
