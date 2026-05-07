# Repository Guidelines

## Project Structure & Module Organization

CooperBench uses a Python `src/` layout. Core package code lives in `src/cooperbench/`: `cli.py` exposes `cooperbench` and `coop`, `runner/` handles benchmark execution, `eval/` contains evaluation and sandbox backends, `agents/` contains agent adapters, and `infra/` contains services such as Redis support. Tests live in `tests/`, with unit areas such as `tests/runner/` and `tests/eval/`, plus backend checks under `tests/integration/`. Benchmark task data and patches live in `dataset/`; docs, scripts, and the paper are in `docs/`, `scripts/`, and `paper/`.

## Build, Test, and Development Commands

Use Python 3.10+ for package development. Install dependencies with:

```bash
uv sync --extra dev
uv run cooperbench --help
```

Run all tests with `uv run pytest`, or a targeted file with `uv run pytest tests/runner/test_core.py`. Run linting with `uv run ruff check src tests` and type checks with `uv run mypy src/cooperbench`. If available, run hooks with `uv run pre-commit run --all-files`.

## Coding Style & Naming Conventions

Follow `pyproject.toml`: Ruff targets Python 3.10, uses a 120-character line length, and enforces `E`, `F`, `I`, and `UP` rules. Use Ruff/isort import ordering and first-party imports under `cooperbench`. Use `snake_case` for modules, functions, variables, and test files; use `PascalCase` for classes. Avoid broad style edits in excluded vendored or adapted trees such as `src/cooperbench/agents/swe_agent/` and `src/cooperbench/agents/openhands_agent_sdk/`.

## Testing Guidelines

Pytest discovers `tests/test_*.py` files and `test_*` functions. Add unit tests near the matching subsystem, for example `tests/runner/` for runner behavior or `tests/eval/` for evaluation logic. Put cloud, Docker, or external-service behavior in `tests/integration/`. Coverage is configured for `src/cooperbench` with branch coverage, omitting agent adapter internals.

## Commit & Pull Request Guidelines

Recent commits use short imperative summaries, often with scope or issue context, such as `Add provider-aware LLM routing` or `Fix datasets task 7309: pin pyarrow < 20.0...`. Keep commits focused and mention the affected subsystem or dataset task when useful. Pull requests should include the problem, change summary, linked issues when applicable, and exact validation run, for example `uv run pytest tests/eval`.

## Security & Configuration Tips

Do not commit API keys, `.env` files, cloud credentials, or generated run logs. Keep LLM provider keys in environment variables such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY`. Document new backend assumptions in `README.md` or `docs/GCP_SETUP.md`.
