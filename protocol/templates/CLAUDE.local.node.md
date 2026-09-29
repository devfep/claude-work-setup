# Local workflow rules for this repo (not committed; linked by bootstrap)

Stack: node. Package manager: <from lockfile>. Base branch: develop.
Build: `npm ci && npm run build`. Test: `npx vitest run --coverage` (coverage floor: <n>%).
Types: `npx tsc --noEmit`. Lint: <command>. Format: <command>.
Dev server: `npm run dev` on port <n>. Verify skill: `verify-<repo>`; feature map at
`~/.claude/skills/verify-<repo>/features/`.
Evidence path: programmes/<programme>/verify/<JIRA>/.
Repo-specific notes: <anything the team's CLAUDE.md does not say>.
