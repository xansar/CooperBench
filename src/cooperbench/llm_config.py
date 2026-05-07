"""Shared LLM provider configuration for CooperBench."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

AZURE_SCOPE = "https://cognitiveservices.azure.com/.default"
AZURE_DEFAULT_ENDPOINT = "https://societalllm.openai.azure.com/"


@dataclass(frozen=True)
class ResolvedLLMConfig:
    """Resolved LiteLLM configuration for a provider."""

    model_name: str
    model_kwargs: dict[str, Any]
    metadata: dict[str, Any]


def resolve_llm_config(
    *,
    model: str,
    provider: str | None = None,
    endpoint: str | None = None,
    api_version: str | None = None,
) -> ResolvedLLMConfig:
    """Resolve CLI/provider settings into LiteLLM-compatible model config."""
    if provider is None:
        return ResolvedLLMConfig(
            model_name=model,
            model_kwargs={},
            metadata={
                "provider": None,
                "endpoint": endpoint,
                "api_version": api_version,
                "model": model,
            },
        )

    normalized_provider = provider.strip().lower()
    if normalized_provider == "azure":
        if not api_version:
            raise ValueError("Azure provider requires --api-version/--version")

        azure_endpoint = endpoint or AZURE_DEFAULT_ENDPOINT
        token_provider = _build_azure_ad_token_provider()
        return ResolvedLLMConfig(
            model_name=f"azure/{model}",
            model_kwargs={
                "api_base": azure_endpoint,
                "api_version": api_version,
                "azure_ad_token_provider": token_provider,
            },
            metadata={
                "provider": "azure",
                "endpoint": azure_endpoint,
                "api_version": api_version,
                "model": model,
            },
        )

    if normalized_provider == "vllm":
        if not endpoint:
            raise ValueError("vLLM provider requires --endpoint")
        return ResolvedLLMConfig(
            model_name=f"hosted_vllm/{model}",
            model_kwargs={"api_base": endpoint},
            metadata={
                "provider": "vllm",
                "endpoint": endpoint,
                "api_version": api_version,
                "model": model,
            },
        )

    raise ValueError(f"Unsupported LLM provider: {provider}")


def _build_azure_ad_token_provider():
    try:
        from azure.identity import AzureCliCredential, get_bearer_token_provider
    except ImportError as exc:
        raise RuntimeError(
            "Azure provider requires azure-identity to be installed"
        ) from exc

    credential = AzureCliCredential()
    return get_bearer_token_provider(credential, AZURE_SCOPE)
