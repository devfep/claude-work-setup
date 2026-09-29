# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

- Use skills proactively when they match the task — suggest relevant ones, don't block on them

## Workspace rules (sandboxed pod)

- Platform rules in `~/ebs/AGENTS.md` and the platform-provided skills under `~/.claude/skills/`
  (`toolchain`, `aws-switch`, and its review-changes skill) override anything here: git goes
  through the proxy in the exact form given there, runtimes are installed with `toolchain`, AWS
  credentials come from `aws-switch`.
- There is no external internet. Packages come from the internal mirrors already configured in
  `~/.npmrc`, `~/.m2`, `~/.gradle` and the PyPI index in the overlay. Never add a registry URL to
  a project file.
- Nothing of this workflow is committed to a team repository. Local-only files
  (`CLAUDE.local.md`, `.claude/settings.local.json`) are excluded through `.git/info/exclude`.
  Programme state lives in the workflow repo.
- Branches: work on `feature/<JIRA-KEY>-<slug>`; `develop`, `master` and `release*` are
  protected and hooks refuse pushes to them. Every commit subject starts with the JIRA key.
- Merging is the team's act through a pull request; the loop opens PRs and never merges.
- The pod has two CPUs: run one build or test suite at a time.
- Proof before claims: a change is verified only when the real app was driven and evidence
  captured (`verify-<repo>` skill, `cdp` CLI). "It compiles" and "tests pass" are not evidence
  of behaviour.

## Philosophy

- **No speculative features** - Don't add features, flags, or configuration unless users actively
  need them
- **No premature abstraction** - Don't create utilities until you've written the same code three
  times
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No phantom features** - Don't document or validate features that aren't implemented
- **Replace, don't deprecate** - When a new implementation replaces an old one, remove the old one
  entirely. No backward-compatible shims, dual config formats, or migration paths. Proactively
  flag dead code — it adds maintenance burden and misleads both developers and LLMs.
- **Verify at every level** - Set up automated guardrails (linters, type checkers, pre-commit
  hooks, tests) as the first step, not an afterthought. Prefer structure-aware tools (ast-grep,
  LSPs, compilers) over text pattern matching. Review your own output critically. Every layer
  catches what the others miss.
- **Bias toward action** - Decide and move for anything easily reversed; state your assumption so
  the reasoning is visible. Ask before committing to interfaces, data models, architecture, or
  destructive/write operations on external services.
- **Finish the job** - Don't stop at the minimum that technically satisfies the request. Handle
  the edge cases you can see. Clean up what you touched. If something is broken adjacent to your
  change, flag it. But don't invent new scope — there's a difference between thoroughness and
  gold-plating.
- **Agent-native by default** - Design so agents can achieve any outcome users can. Tools are
  atomic primitives; features are outcomes described in prompts. Prefer file-based state for
  transparency and portability. When adding UI capability, ask: can an agent achieve this outcome
  too?

## Code Quality

### Hard limits

1. ≤100 lines/function, cyclomatic complexity ≤8
2. ≤5 positional params
3. 100-char line length
4. Absolute imports only — no relative (`..`) paths
5. Google-style docstrings on non-trivial public APIs

### Zero warnings policy

Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly
can't be fixed, add an inline ignore with a justification comment. Never leave warnings
unaddressed; a clean output is the baseline, not the goal.

### Comments

Code should be self-documenting. No commented-out code—delete it. If you need a comment to explain
WHAT the code does, refactor the code instead.

### Error handling

- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

### Reviewing code

Evaluate in order: architecture → code quality → tests → performance. Before reviewing, sync to
latest remote (`git fetch origin`).

For each issue: describe concretely with file:line references, present options with tradeoffs
when the fix isn't obvious, recommend one, and ask before proceeding.

### Testing

**Test behavior, not implementation.** Tests should verify what code does, not how. If a refactor
breaks your tests but not your code, the tests were wrong.

**Test edges and errors, not just the happy path.** Empty inputs, boundaries, malformed data,
missing files, network failures — bugs live in edges. Every error path the code handles should
have a test that triggers it.

**Mock boundaries, not logic.** Only mock things that are slow (network, filesystem),
non-deterministic (time, randomness), or external services you don't control.

**Verify tests catch failures.** Break the code, confirm the test fails, then fix. Use mutation
testing (`mutmut`, PIT, stryker) to verify systematically. Use property-based testing
(`hypothesis`, `fast-check`) for parsers, serialization, and algorithms.

## Development

When adding dependencies or tool versions, check what the internal mirror serves
(`npm view <pkg> versions`, `uv pip index versions <pkg>`,
`mvn versions:display-dependency-updates`) rather than assuming from memory.

### CLI tools

| tool | usage |
|------|-------|
| `rg` | `rg "pattern"` for literal strings and log messages |
| `ast-grep` | `ast-grep --pattern '$FUNC($$$)' --lang ts` for code structure |
| `jq` | JSON on the command line |
| `shellcheck` / `shfmt` | lint and format every shell script |
| `prek` | git hooks (`prek install`, `prek run`) |
| `gh` | GitHub Enterprise (`GH_HOST` is set from the overlay) |
| `cdp` | drive the browser sidecar: `cdp doctor`, `cdp new <url>`, `cdp screenshot out.png` |

### Command output (when `rtk` is installed)

`rtk` condenses command output to save tokens, keeping every signal and dropping costly noise.
Treat condensed output as the complete result: run commands normally and batch related commands
into one call. Truncated results state their recovery path in their own output. Re-run a command
as `rtk proxy <cmd>` only when its result is unusable: empty when output was clearly expected,
contradicting its exit code, or garbled. If `rtk` is not on PATH, output is unfiltered.

Prefer `ast-grep` over ripgrep when searching for code structure. There is no `trash`; move files
aside with `mv` into a scratch directory instead of deleting.

### TypeScript / React

| purpose | tool |
|---------|------|
| package manager | the one the repo's lockfile names (`package-lock.json` → npm) |
| lint | `oxlint` if installed, else the repo's eslint config |
| format | `oxfmt` if installed, else the repo's prettier config |
| test | `vitest` (`vitest run --coverage`) |
| types | `tsc --noEmit` |

Never introduce a second package manager into a repo. tsconfig strictness: `strict`,
`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`,
`verbatimModuleSyntax`, `isolatedModules`. Colocated `*.test.ts(x)` files. A React warning in the
browser console is a G1 failure, the same as a compiler warning.

### Spring Boot / Java 21

| purpose | tool |
|---------|------|
| build | `mvn -q -DskipTests compile` or `gradle compileJava`, warnings as errors (below) |
| lint | Checkstyle or Error Prone as configured in the repo |
| format | Spotless (`mvn spotless:check`) |
| test | `mvn test` / `gradle test`, JaCoCo coverage report |
| mutation | PIT on the changed package |

Warnings as errors: `-Dmaven.compiler.failOnWarning=true` for Maven, `-Werror` for Gradle.

No Docker in the pod: use H2 or an embedded store in place of Testcontainers, WireMock for
outbound HTTP, and `spring-boot:run` with a `local` profile for run evidence. Constructor injection
only. No field injection, no `@Autowired` on fields.

### Python 3.12

| purpose | tool |
|---------|------|
| deps & venv | `uv` (`uv venv`, `uv add`, `uv run`) |
| lint & format | `ruff check` · `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` with `moto` for AWS and `dynamodb-local` where a table is needed |
| mutation | `mutmut run --paths-to-mutate <changed module>` |

Always use uv, ruff and ty over pip, black/flake8 and mypy. Glue jobs and Lambdas: keep handler
logic in importable modules with the entry point as a thin wrapper, so tests import the module
without the Glue or Lambda runtime. Pin exact versions.

### Terraform

| purpose | tool |
|---------|------|
| format | `terraform fmt -check -recursive` |
| validate | `terraform init -backend=false && terraform validate` |
| lint | `tflint` if installed |
| plan | `terraform plan -out=<evidence>/plan.tfplan` in the sandbox account (below) |

Plans run against the sandbox account from `aws-switch`, with `terraform show -no-color` saved
beside the plan file. A plan that touches anything other than the intended resources fails the
task. Never `apply` from the loop (the deny list enforces it). No hardcoded account IDs or ARNs;
variables and data sources only.

### Snowflake

| purpose | tool |
|---------|------|
| lint & format | `sqlfluff lint` · `sqlfluff fix --check` with the repo's dialect config |
| tests | the repo's local runner if it has one; otherwise lint plus review, stated in the PR |

No connection to a remote database exists from the pod; never attempt one.

### Bash

All scripts start with `set -euo pipefail`. Lint: `shellcheck script.sh && shfmt -d script.sh`.

## Workflow

**Before committing:**
1. Re-read your changes for unnecessary complexity, redundant code, and unclear naming
2. Run relevant tests — not the full suite
3. Run linters and type checker — fix everything before committing

**Commits:**
- Imperative mood, ≤72 char subject line, one logical change per commit
- Never amend/rebase commits already pushed to shared branches
- Never push directly to main — use feature branches and PRs
- Never commit secrets, API keys, or credentials — use `.env` files (gitignored) and environment
  variables
- Subject = JIRA key + what changed; body = why, in plain sentences. Use the
  `technical-writing` skill when the firm's marketplace provides it.

**Hooks and worktrees:**
- Where a repo has a `.pre-commit-config.yaml`, run `prek install` once and `prek run` before
  committing.
- Parallel subagents require worktrees. Each subagent MUST work in its own worktree
  (`git worktree add <checkout>/.worktrees/<jira> <branch>`), not the main checkout. Never share
  working directories.

**Pull requests:**
Describe what the code does now — not discarded approaches, prior iterations, or alternatives.
Only describe what's in the diff.

Use plain, factual language. A bug fix is a bug fix, not a "critical stability improvement."
Avoid: critical, crucial, essential, significant, comprehensive, robust, elegant.

The body carries the Done line, the gate summary with evidence path, and what a reviewer should
look at first, in plain sentences (the `technical-writing` skill, when installed, sets the bar).
