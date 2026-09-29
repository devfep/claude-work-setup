# Build protocol

How every task in a programme is built, verified and handed to the team. The commands in
`claude/commands/` (`/dispatch`, `/checkpoint`, `/resume`) execute this protocol; where they and
this file disagree, this file wins and the command is fixed.

## 1. One task, one fresh context

- A task is the unit of work: one ROADMAP entry, one repo, one JIRA key, one branch, one PR.
- Each task gets a fresh implementer subagent briefed only from the dispatch brief (§ 4). It
  inherits nothing from earlier tasks: what it needs is in the brief, the repo's CLAUDE.md and
  CLAUDE.local.md, or the contract files the task cites.
- The implementer works in its own worktree, `<checkout>/.worktrees/<jira>`, never in the main
  checkout and never in another lane's worktree.
- Review fixes go back to the SAME implementer lane, and the re-check to the SAME reviewer, so
  neither has to rebuild context. A new task always gets a new lane.
- The orchestrator's memory is the STATE block in `SESSION-RESUME.md`, not its context window.
  Anything not written there is assumed lost at the next context clear or workspace rebuild.

## 1.5 The craft standard

Services, jobs and internal tools are judged on four things.

- **Correct.** The Done line is true for every entry point the feature map lists, including the
  edge and error paths, not only the convenient one.
- **Boring.** Follow the repo's existing patterns, framework defaults and libraries. A new
  dependency, pattern or abstraction needs a reason written in the PR.
- **Observable.** Failures surface with context: log lines say what operation failed on what
  input, errors tell the caller what to do next, and health endpoints and metrics stay truthful
  where the service has them.
- **No cleverness.** The smallest explicit change that makes the Done line true. No speculative
  flags or configuration, no dense one-liners, no drive-by refactors outside the task.

## 2. The three roles per task

- **Orchestrator.** Reads the ROADMAP, picks and dispatches tasks (`/dispatch`), owns the STATE
  block and BOARD.json, relays reviewer findings to the implementer, marks the implementer's
  draft PR ready for the team (`gh pr ready`) after the reviewer's Yes, and closes the roadmap box
  with the PR link. It never writes product code and never merges.
- **Implementer.** Owns one task in one worktree on `feature/<JIRA>-<slug>`. Shows the Verify
  line red, makes it green, runs every gate for its stack (§ 3), saves the evidence, commits and
  pushes after every green gate, opens the PR as a draft (G7, `gh pr create --draft`), and
  reports in the format of § 5.
- **Reviewer.** A separate fresh agent in its own worktree of the draft PR's branch. Re-runs the
  whole gate row independently (§ 3.4), performs the hand mutation (§ 3.5), checks the feature
  map against the app, and answers Yes or No with findings as file:line references. It does not
  fix what it finds and never changes the PR's state; the fixes go back to the implementer.

## 3. The verification gate

A task carries, before any code, a **Verify** line (an executable command or assertion) and a
**Done** line (what a user or operator observes). The implementer makes Verify fail first, then
pass, then runs every gate for its stack. It iterates build → test → fix on its own. If the same
gate fails three times with the same cause it stops and reports blocked with the full output; a
fourth attempt is never made.

Evidence for every gate goes to `programmes/<programme>/verify/<JIRA>/` as the raw command output
plus, where named, files. No completion claim without the command output. "It compiles" and
"tests pass" are not proof of behaviour; G4 is.

| Gate | Node/React | Spring Boot | Python | Terraform | Snowflake |
|---|---|---|---|---|---|
| G1 zero warnings | `tsc --noEmit`; lint; browser console clean (`cdp console`) | compile with failOnWarning; Checkstyle/Error Prone | `ruff check`; `ty check` | `fmt -check`; `validate`; tflint | `sqlfluff lint` |
| G2 tests red→green | `vitest run --coverage`, floor from CLAUDE.local.md | `mvn test`/`gradle test`, JaCoCo floor; H2, WireMock | `pytest --cov`, moto, dynamodb-local, floor | `plan` in the sandbox account, saved | local runner if the repo has one, else lint + review, stated in the PR |
| G3 format | `oxfmt --check` or prettier | `spotless:check` | `ruff format --check` | `terraform fmt -check` | `sqlfluff fix --check` |
| G4 run evidence | the repo's `verify-<repo>` skill: Launch, Doctor, Drive every entry point the feature-map file lists for the change, Evidence (screenshot, accessibility snapshot, console, network, side effects), Cleanup; zero failed requests | `spring-boot:run` (local profile); actuator health plus each changed endpoint curled; responses saved | job run on a fixture input; output diffed against expected | `terraform show` of the plan lists only the intended resources | n/a |
| G5 Verify line | passes, output saved | same | same | same | same |
| G6 mutation spot-check | stryker on the changed module if mirrored | PIT on the changed package | mutmut on the changed module | n/a | n/a |
| G7 draft PR | implementer: `gh pr create --draft` from `feature/<JIRA>-<slug>` into the base branch; body written with `technical-writing`: Done line, gate summary, evidence path. Orchestrator: `gh pr ready` after the reviewer's Yes | same | same | same | same |

"Working" = G4 and G5 pass. "Done" = every gate passes, the reviewer has re-run the whole row
independently and answered Yes, the orchestrator has marked the draft PR ready, and the roadmap
box is closed with the PR link. Merging is the team's act.

### 3.1 Verification skills and the feature map

Every repo with a user-facing surface has a `verify-<repo>` skill (shape in
`protocol/templates/verify-skill/`; written by hand or generated by a verification-skill
generator the firm's marketplace provides), stored in the workflow repo under
`projects/<repo>/skills/` and linked into `~/.claude/skills/`. Its feature map (`features/README.md` plus one file per feature)
answers, from the user's point of view: what exists, how to reach it, how to drive it, what
proves it works. A task's brief names the feature-map files its change touches; G4 drives every
entry point those files list, not just the convenient one. When a change adds or moves a feature,
the implementer updates the map in the same task and the reviewer checks the map against the
app. A maintenance pass runs when the map is older than seven days (a generator's maintain
command if installed, otherwise a manual re-walk of every feature file); it never edits product
code.

### 3.2 The browser sidecar and the cdp CLI

Chrome DevTools Protocol is exposed at the overlay's `CDP_URL`. Attach; never launch a browser.
`cdp` (tools/cdp.mjs) provides doctor, new, close, nav, screenshot, snapshot, console, network,
click, type, eval, wait. Verify skills wrap it with app-specific commands. Each lane opens its own
target (`cdp new <url>`, exported as `CDP_TARGET`) and closes it in Cleanup, because the Chrome is
shared. `cdp console N` and `cdp network N` exit non-zero when they capture an error or a failed
request, so a gate can use the exit code.

### 3.3 Tools that may be absent

Availability of tflint, stryker, mutmut and PIT is confirmed by `docs/POD-CHECKLIST.md`. A gate
whose tool is absent is reported as `G6: not available (mutmut not mirrored)` in the report and
the PR, never skipped silently.

### 3.4 The reviewer's independent gate

The reviewer checks out the lane's branch in its own worktree, re-runs every gate from the table,
drives the same feature-map entries with the verify skill, and compares its evidence to the
implementer's. A Yes requires its own outputs, not the implementer's. The agent that judges a
change is never the one that wrote it.

### 3.5 Mutation discipline: a green suite must be load-bearing

G6's tool run is scoped to the changed lines (two CPUs; a whole-module run is a separate,
scheduled job). Independent of the tool, the reviewer performs a **hand mutation** on every task,
and it is mandatory even where no mutation tool exists (Terraform and Snowflake included, applied
to the Verify line):

1. Pick the condition the task pins (the branch, comparison, default or fallback the Done line
   depends on).
2. Invert or remove it in the reviewer's worktree, run the narrowest suite that should catch it,
   and save the output.
3. The output must show the specific test **by name** going red. "Tests failed" is not evidence;
   a crash, a compile error or a timeout is a different red and does not count.
4. Restore the file and prove the restore (`git diff --exit-code` on the mutated path) **before**
   any further run; a run against an unrestored mutant is a false result in whichever direction
   it goes.
5. Record the mutated line, the test name and the red log in `verify/<JIRA>/mutation.md`.

A surviving mutant on the changed lines is a review finding that fails the task, not a metric.
Watch for the vacuous shapes seen in earlier builds: a check that asserts a tautology
(`A || !A`), a fixture that had to fake the data it was meant to exercise, a red-first claim
whose red was a crash, and a fallback `a ?? b` whose tests cover only one arm.

## 4. Prompt for the implementer

### 4.0 Dispatch checklist — every brief carries these lines

- The task verbatim: id, jira, repo, stack, Verify, Done, `after:` and the contract files it
  cites.
- The repo's CLAUDE.local.md pasted, and the platform rules cited by path (`~/ebs/AGENTS.md`).
- The gate row for the stack, the evidence path, the verify skill name and the feature-map files
  that cover the change.
- Branch name `feature/<JIRA>-<slug>`; commit subjects start with the JIRA key, body says why
  in plain sentences; push after every green gate; never touch `develop`, `master`,
  `release*`. Open the PR as a draft at G7 and never mark it ready; that is the orchestrator's
  step after the reviewer's Yes.
- One suite at a time; no background monitors; report when done or blocked, never idle.
- Red first: show the Verify line failing before the change, with the failing test's own name in
  the log.
- Name the condition the task pins, so the reviewer's hand mutation (§ 3.5) has a target; commit
  before any mutation run and restore before the next run.
- The report format from § 5, with command output, not summaries.
- Stop conditions: three identical failures → blocked report; any question only Felix can answer
  → write it in the report under "Needs Felix", do not guess.

## 5. Report format

Reports carry command output, not summaries. A claim without its output is treated as not done.

### 5.1 Implementer report

```
TASK-<id> <JIRA> — done | blocked
Branch: feature/<JIRA>-<slug> @ <sha> (pushed: yes/no)
PR:     <url> (draft, opened by this lane at G7; "not opened" while blocked)
Red:    <Verify command> → <failing output, with the test's own name>
Green:  <Verify command> → <passing output>
Gates:
  G1 <command> → pass/fail, evidence <path>
  G2 ... G7    (one line each; an absent tool is "not available (<reason>)")
Pinned condition: <file:line and the condition the reviewer should mutate>
Feature map: <files updated, or "unchanged">
Needs Felix: <questions only Felix can answer, each with what it blocks, or "none">
Blocked on: <the failing gate, its three outputs, or "—">
```

### 5.2 Reviewer report

```
REVIEW TASK-<id> <JIRA> @ <sha> — Yes | No
PR: <url> (still draft; on Yes the orchestrator runs gh pr ready)
Gates re-run: G1 … G7, each pass/fail with the reviewer's own evidence path
Hand mutation: <file:line mutated> → <test name> red (log <path>); restore proven by
  git diff --exit-code <path>
Feature map vs app: consistent | <differences>
Findings: <file:line — problem — required change>, one per line, or "none"
```

## 6. Multi-repo programmes

- `ROADMAP.md` tasks carry `repo:`, `stack:`, `jira:`, `after:`. A task touches one repo.
- A cross-repo feature opens with a contract task in the workflow repo writing
  `programmes/<programme>/contracts/<name>.md` (payload shapes, table DDL, job parameters).
  Implementation tasks cite it and list it in `after:`.
- The orchestrator runs from the programme folder with the repos attached via `--add-dir`. Each
  lane runs in `<checkout>/.worktrees/<jira>`.
- Capacity on a two-CPU pod: one implementer and one reviewer live at once, one test suite in
  flight.

## 7. Checkpoint and resume

`/checkpoint <programme>` and `/resume <programme>` in `claude/commands/`. The STATE block is the
whole truth; the loop commits it after every dispatch, report, review verdict and PR. A question
only Felix can answer goes under Pending from Felix with a Teams ping; the loop continues with
independent tasks or parks.
