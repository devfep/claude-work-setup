
# Review and Fix PR

@description Review an existing PR with parallel agents, fix findings, and push.
@arguments $PR_NUMBER: GitHub PR number to review and fix

The PR lives on GitHub Enterprise: `GH_HOST` comes from the overlay
(`~/ebs/.claude/overlay.env`), so `gh` already targets the enterprise
host. Read PR #$PR_NUMBER thoroughly using
`gh pr view $PR_NUMBER --repo <owner/name>`. Understand the full
context: description, linked JIRA issue, commit history, and the diff
against the base branch.

Detect the upstream repository: if a git remote named `upstream`
exists, use it as the canonical repo. Otherwise, fall back to
`origin`. Resolve the canonical repo's `owner/name` (e.g. from
`git remote get-url upstream`) and store it — pass
`--repo <owner/name>` on every `gh` command. Run
`git fetch <upstream-remote>` (in the proxy form `~/ebs/AGENTS.md`
gives) to ensure you are working with up-to-date code.

Check out the PR branch locally. It must be a `feature/*` branch; if
it is not, stop and report, because fixes are only ever pushed to the
PR's `feature/*` branch.

Execute every step below sequentially. Do not stop or ask for
confirmation at any step.

## 1. Review

Launch these agents **in parallel** (single message, multiple tool
calls), each with `subagent_type: general-purpose` and the focus
below. Tell each agent which files changed (from
`git diff --name-only <base>...HEAD`) and to read `~/.claude/CLAUDE.md`
and the repo's CLAUDE.md and CLAUDE.local.md for the guidelines:

| agent | focus |
|-------|-------|
| code reviewer | Code quality, style, project guidelines |
| silent-failure hunter | Silent failures, swallowed errors, bad fallbacks |
| test analyzer | Test coverage gaps and missing edge cases |

The diff never leaves the pod: no external review services.

### Merge findings

Collect results from all 3 agents. Deduplicate overlapping findings
— if multiple agents flag the same issue, keep the most specific
description and note the consensus. Rank every finding by severity:

- **P1** — blocks merge (correctness bugs, security issues)
- **P2** — important (missing error handling, test gaps, logic flaws)
- **P3** — nice to have (style, naming, minor simplifications)
- **P4** — informational (observations, suggestions for future work)

## 2. Fix findings

Address all P1–P3 findings. For each finding, either:

- **Fix it** — apply the change, or
- **Dismiss it** — explain why it's a false positive or not worth
  the churn (e.g. a stylistic disagreement or an impossible edge
  case). Document the reasoning inline.

When a fix requires external context — unfamiliar library behavior,
unclear API semantics, or an error you don't recognize — read the
library's source or documentation from the internal mirror rather
than guessing.

P4 findings are informational — note them but do not fix unless
trivial.

After addressing all findings, review your own fixes: read the
diff of changes made in this step and verify each fix is correct,
doesn't introduce new issues, and doesn't regress other parts of
the PR. If you spot a problem, fix it before proceeding.

## 3. Verify

### 3a. Discover project checks (CI is the source of truth)

Before running anything, read the project's CI configuration to
learn what the project *actually* runs. This takes priority over
the fallback defaults below.

1. **Read the CI config.** Find the primary CI definition
   (`.github/workflows/*.yml`, `Jenkinsfile`, or whatever the repo
   uses). Extract:
   - Test commands with profiles or flags (e.g.
     `mvn -P ci verify`)
   - Lint/format commands with non-default flags
   - Any step that runs a command then checks `git diff --exit-code`
     — these are **codegen sync checks** (schema generation,
     snapshot updates, OpenAPI clients, etc.). Record the command.
   - Docs/site build commands
2. **Read the Makefile** (if present). Cross-reference targets
   used in CI — these are the ones that matter.
3. **Read CLAUDE.md and CLAUDE.local.md** (repo root or `.claude/`).
   They may define project-specific quality gates.

Store the discovered commands. They override the fallback defaults
for any overlapping step.

### 3b. Run the quality pipeline

Detect the stack from manifest files (`package.json` →
TypeScript/React, `pom.xml`/`build.gradle` → Spring Boot,
`pyproject.toml`/`setup.py` → Python, `*.tf` → Terraform, `*.sql`
with a `.sqlfluff` → Snowflake). A repo may use several; run checks
for each. The pod has two CPUs: run one suite at a time.

Run checks in this order. For each step, use the CI-discovered
command if one was found; otherwise fall back to the default.

1. **Build** — compile or bundle
2. **Test** — run the full test suite with the same flags CI uses.
   Iterate on failures until green.
3. **Lint and format** — fix any issues
4. **Extended checks** — per-stack extras (types, supply chain)
5. **Codegen sync** — for every codegen check discovered in 3a,
   run the command and verify `git diff --exit-code`. If the diff
   is non-empty, the generated files are stale — regenerate and
   stage them.
6. **Docs build** — if the PR changes documentation files and a
   docs build command exists, run it to verify the docs compile.

### Fallback defaults (when CI config is absent or unclear)

Use the tool table for the detected stack in `~/.claude/CLAUDE.md`
(TypeScript / React, Spring Boot / Java 21, Python 3.12, Terraform,
Snowflake). Supply chain: `npm audit --audit-level=moderate` for
Node, `pip-audit` for Python. Never `terraform apply`.

If a tool is not installed, skip it with a note in the PR comment
rather than failing the pipeline.

## 4. Commit and push

- Commit the fixes as a separate commit (do not squash into the
  original — preserve review history)
- Write the message with the `technical-writing` skill:
  - Subject: `<JIRA-KEY> Resolve code review findings for PR #$PR_NUMBER`,
    with the JIRA key taken from the branch name
  - Body: findings by severity, what was fixed vs dismissed (with
    brief reasoning), and confirmation that the quality pipeline
    passes
- Push to the PR's `feature/*` branch only (regular push, not
  force-push)
- Delete any todo files in `todos/` that were created by the
  review and are now resolved

## 5. PR comment

Write the review summary with the `technical-writing` skill and post
it as a PR comment using `gh pr comment $PR_NUMBER --repo <owner/name>`.

Format the comment body as:

```
## Review Summary

### Findings

[For each severity level that has findings, list them as a table:]

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | P1 | [description] | Fixed: [what was done] |
| 2 | P2 | [description] | Dismissed: [reasoning] |
| ... | ... | ... | ... |

### Verification

- **Tests**: [pass/fail count]
- **Lint**: [clean/issues]
- **Format**: [clean/issues]

### Commit

[commit SHA and subject line]
```
