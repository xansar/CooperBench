"""Tests for coop conversation extraction."""

from cooperbench.runner.coop import _extract_conversation


def test_extract_conversation_skips_none_assistant_content():
    results = {
        "agent1": {
            "feature_id": 1,
            "messages": [{"role": "assistant", "content": None}],
            "sent_messages": [{"to": "agent2", "content": "hello"}],
        },
        "agent2": {"feature_id": 2, "messages": [], "sent_messages": []},
    }

    conversation = _extract_conversation(results, ["agent1", "agent2"])

    assert conversation == [
        {
            "from": "agent1",
            "to": "agent2",
            "message": "hello",
            "timestamp": None,
            "feature_id": 1,
        }
    ]


def test_extract_conversation_reads_text_blocks():
    results = {
        "agent1": {
            "feature_id": 1,
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": "[Message from agent2]: received"}],
                    "timestamp": "2026-05-07T00:00:00",
                }
            ],
        },
        "agent2": {"feature_id": 2, "messages": []},
    }

    conversation = _extract_conversation(results, ["agent1", "agent2"])

    assert conversation == [
        {
            "from": "agent2",
            "to": "agent1",
            "message": "received",
            "timestamp": "2026-05-07T00:00:00",
            "feature_id": 1,
            "received": True,
        }
    ]
