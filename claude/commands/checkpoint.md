Felix is about to clear the context or step away. Programme: `$ARGUMENTS` (a folder under
`programmes/` in the workflow repo). Do this now, in one pass, then reply with exactly one line.

1. Rewrite the `## STATE` block at the top of `programmes/$ARGUMENTS/SESSION-RESUME.md` so it is
   true at this instant: checkpoint time, the `**Orchestrator:**` line set to
   `none (checkpointed at <sha> by <session>)`, per-repo tips (branch and sha for every repo the
   programme touches), the live-lanes table (lane name, task, repo, worktree path, branch, HEAD,
   stage), open PRs awaiting the team, in-flight background jobs with their log paths,
   **Pending from Felix** (questions only he can answer, each with what is blocked on it),
   standing rules, numbered next actions. Rewrite, never append; history goes under `## Log`.
   Plain sentences, exact names, no filler (the `technical-writing` skill, if installed).
2. Update `programmes/$ARGUMENTS/BOARD.json` to match.
3. In the workflow repo: `git add programmes/$ARGUMENTS && git commit -m "Checkpoint $ARGUMENTS"`
   and push its branch. Nothing else is committed.
4. If anything under Pending from Felix is new since the last checkpoint, run
   `~/.claude/hooks/teams-notify.sh --text "PENDING ($ARGUMENTS): <one line per item>"`.
5. If a gate or a lane is mid-flight and the block cannot yet say where it landed, reply exactly
   `hold, N minutes` with your estimate and finish that step first; otherwise reply exactly
   `checkpointed at <sha>` with the workflow repo commit sha. No other text.
