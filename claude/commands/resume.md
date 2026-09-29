Resume as the build orchestrator for programme `$ARGUMENTS` after a context clear or a workspace
rebuild. Do these in order, without asking.

0. **One orchestrator at a time.** Read the `**Orchestrator:**` line in the `## STATE` block of
   `programmes/$ARGUMENTS/SESSION-RESUME.md` in the workflow repo. If it names a session other
   than `none`, check whether that session is live: a transcript under `~/.claude/projects/`
   modified in the last 30 minutes is live. If it is, reply "another orchestrator (<name>) is
   live since <time>; I am read-only until Felix says 'take over'" and stop. Otherwise take the
   role: rewrite the line with your session name and the time in the first commit you make.
1. Read the whole `## STATE` block; it supersedes everything under `## Log`. Read
   `protocol/BUILD-PROTOCOL.md` § "Dispatch checklist" and the programme's `PLAN.md`.
2. Read the memory index (`MEMORY.md` for this project) and any memory the STATE block names.
3. For every repo in the STATE tips table: `git -C <checkout> rev-parse --short HEAD` and
   `git status --short`; report any mismatch with the block before acting. After a workspace
   rebuild the checkouts may be fresh clones: re-create the worktrees the lanes table lists from
   their branches (`git worktree add <checkout>/.worktrees/<jira> <branch>`).
4. `ListAgents`. For every lane the table lists as live: if listed, `SendMessage` it "resend your
   last full report and current commit sha"; never re-dispatch a live lane. If gone, its branch
   holds the work: finish from there with one fresh lane briefed from the table row.
5. Continue the standing loop from the numbered next actions: implementer report → reviewer
   re-runs the gate → fix passes back to the SAME lane → re-check by the SAME reviewer → on Yes,
   PR opened (never merged) → roadmap box closed with the PR link → worktree reclaimed → STATE
   rewritten.
6. Standing rules: one implementer and one reviewer at a time, one test suite in flight; every
   task on `feature/<JIRA>-<slug>`; commit and push after every task; evidence into
   `programmes/$ARGUMENTS/verify/<JIRA>/`; a question only Felix can answer goes to Pending from
   Felix with a Teams ping, then continue with independent tasks or checkpoint and park; never
   push to a protected branch; never merge; never `apply` Terraform.
7. Say in one short message what you found and what you are doing first, then do it.
