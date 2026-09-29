Dispatch the next task of programme `$ARGUMENTS` (or a named task: `$ARGUMENTS` may be
`<programme> <TASK-ID>`).

1. In the workflow repo read `programmes/<programme>/ROADMAP.md`. Pick the first unchecked task
   whose `after:` tasks are all closed (PR merged, per `gh pr view --json state`). If the pick is
   a contract task, it runs in the workflow repo and writes to `programmes/<programme>/contracts/`.
2. Confirm capacity: no implementer lane live (`ListAgents`), no test suite running
   (`pgrep -f 'vitest|pytest|mvn|gradle|terraform'` empty).
3. Verification skill freshness: if the task's repo has `~/.claude/skills/verify-<repo>/` and its
   `features/README.md` is older than seven days (`find -mtime +7`), run
   `/maintain-verification-skill` for that repo first and commit its corrections to the workflow
   repo. If the repo has an app surface and no verify skill yet, the first task for that repo is
   `/create-verification-skill`, output placed under `projects/<repo>/skills/verify-<repo>/` in
   the workflow repo, then `bootstrap.sh` to link it.
4. Create the lane's worktree: in the task's repo checkout, `git fetch origin && git worktree add
   <checkout>/.worktrees/<jira> -b feature/<JIRA>-<slug> origin/develop` (or the base branch the
   task names).
5. Build the brief from `protocol/BUILD-PROTOCOL.md` § "Prompt for the implementer", pasting: the
   task verbatim (id, jira, repo, stack, Verify line, Done line, `after:` contracts), the
   CLAUDE.local.md of that repo, the gate row for its stack, the evidence path
   `programmes/<programme>/verify/<JIRA>/`, the name of the verify skill and the feature-map
   files that cover the change, and the report format. Every line of the dispatch checklist must
   be present.
6. Spawn ONE fresh implementer subagent with that brief, named `impl-<jira lowercase>`. Record the
   lane in the STATE table and BOARD.json, commit the workflow repo
   (`Checkpoint <programme>: dispatched <JIRA>`), and say in one line what was dispatched.
