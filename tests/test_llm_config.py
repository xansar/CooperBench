"""Tests for shared LLM provider resolution."""

from unittest.mock import sentinel

import pytest

from cooperbench.llm_config import resolve_llm_config


def test_legacy_model_passthrough():
    resolved = resolve_llm_config(model="gpt-4o")
    assert resolved.model_name == "gpt-4o"
    assert resolved.model_kwargs == {}
    assert resolved.metadata["provider"] is None


def test_vllm_resolution():
    resolved = resolve_llm_config(
        model="qwen2.5-coder",
        provider="vllm",
        endpoint="http://localhost:8000/v1",
    )
    assert resolved.model_name == "hosted_vllm/qwen2.5-coder"
    assert resolved.model_kwargs == {"api_base": "http://localhost:8000/v1"}
    assert resolved.metadata["provider"] == "vllm"


def test_vllm_requires_endpoint():
    with pytest.raises(ValueError, match="requires --endpoint"):
        resolve_llm_config(model="qwen2.5-coder", provider="vllm")


def test_azure_requires_endpoint():
    with pytest.raises(ValueError, match="requires --endpoint"):
        resolve_llm_config(model="deploy", provider="azure", api_version="2024-12-01-preview")


def test_azure_requires_api_version():
    with pytest.raises(ValueError, match="requires --api-version/--version"):
        resolve_llm_config(model="deploy", provider="azure", endpoint="https://example.openai.azure.com")


def test_azure_resolution(monkeypatch):
    monkeypatch.setattr(
        "cooperbench.llm_config._build_azure_ad_token_provider",
        lambda: sentinel.azure_token_provider,
    )
    resolved = resolve_llm_config(
        model="my-deployment",
        provider="azure",
        endpoint="https://example.openai.azure.com",
        api_version="2024-12-01-preview",
    )
    assert resolved.model_name == "azure/my-deployment"
    assert resolved.model_kwargs == {
        "api_base": "https://example.openai.azure.com",
        "api_version": "2024-12-01-preview",
        "azure_ad_token_provider": sentinel.azure_token_provider,
    }
    assert resolved.metadata["provider"] == "azure"
