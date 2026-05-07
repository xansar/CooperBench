"""Tests for mini_swe_agent_v2 model serialization."""

import json

from cooperbench.agents.mini_swe_agent_v2.models.litellm_model import LitellmModel


def test_model_serialize_handles_callable_model_kwargs():
    def token_provider():
        return "token"

    model = LitellmModel(
        model_name="azure/gpt-5.4",
        model_kwargs={
            "api_base": "https://example.openai.azure.com/",
            "api_version": "2024-12-01-preview",
            "azure_ad_token_provider": token_provider,
        },
    )

    serialized = model.serialize()

    json.dumps(serialized)
    model_config = serialized["info"]["config"]["model"]
    assert model_config["model_kwargs"]["api_base"] == "https://example.openai.azure.com/"
    assert "token_provider" in model_config["model_kwargs"]["azure_ad_token_provider"]
