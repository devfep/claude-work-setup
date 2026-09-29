# Local workflow rules for this repo (not committed; linked by bootstrap)

Stack: python. Runtime: <Glue job | Lambda | library>. Base branch: develop.
Setup: `uv venv && uv sync`. Lint: `uv run ruff check`. Types: `uv run ty check`.
Format: `uv run ruff format --check`. Test: `uv run pytest --cov` (coverage floor: <n>%), with
`moto` for AWS and `dynamodb-local` for <tables>.
Mutation: `uv run mutmut run --paths-to-mutate <changed module>`.
Run evidence: `uv run python -m <entry module> <fixture input>`, output diffed against
<expected output file>.
Evidence path: programmes/<programme>/verify/<JIRA>/.
Repo-specific notes: <anything the team's CLAUDE.md does not say>.
