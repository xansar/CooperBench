#!/usr/bin/env python3
"""Quick smoke test for configured LiteLLM providers."""

import argparse
import sys

from dotenv import load_dotenv

load_dotenv()

import litellm

from cooperbench.llm_config import resolve_llm_config


def test_model(
    *,
    model: str,
    provider: str | None,
    endpoint: str | None,
    api_version: str | None,
    prompt: str = "Say hello in one sentence.",
) -> bool:
    """Test a specific provider/model combination and return True if it works."""
    resolved = resolve_llm_config(
        model=model,
        provider=provider,
        endpoint=endpoint,
        api_version=api_version,
    )
    print(f"Testing: {resolved.model_name}")
    print("-" * 40)

    try:
        response = litellm.completion(
            model=resolved.model_name,
            messages=[{"role": "user", "content": prompt}],
            **resolved.model_kwargs,
        )

        print(f"Response: {response.choices[0].message.content}")
        print(f"Model:    {response.model}")
        print(f"Usage:    {response.usage.prompt_tokens} in / {response.usage.completion_tokens} out")
        return True

    except Exception as e:
        print(f"FAILED: {type(e).__name__}: {str(e)[:300]}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Smoke test a model via LiteLLM")
    parser.add_argument("--model", required=True, help="Model or deployment name")
    parser.add_argument("--provider", choices=["azure", "vllm"], help="Provider routing mode")
    parser.add_argument("--endpoint", help="Provider endpoint URL")
    parser.add_argument("--api-version", "--version", dest="api_version", help="Provider API version")
    parser.add_argument("--prompt", default="Say hello in one sentence.", help="Prompt to send")
    args = parser.parse_args()

    ok = test_model(
        model=args.model,
        provider=args.provider,
        endpoint=args.endpoint,
        api_version=args.api_version,
        prompt=args.prompt,
    )
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
