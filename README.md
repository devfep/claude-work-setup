# claude-work-setup

A portable Claude Code setup for a sandboxed Linux workspace whose only persistent volume is
`~/ebs`: global standards, guardrail hooks, commands, a build protocol with a verification gate,
a browser control CLI, and an idempotent bootstrap. Nothing here is installed into a team
repository.

## Two copies

- **This repo (generic).** Placeholders only. No firm names, hostnames, project names, URLs or
  people's identifiers may be committed here; real values live in the overlay, which is
  git-ignored.
- **The firm fork.** Cloned from this one into internal source control. It adds
  `projects/<repo>/` folders, `programmes/<name>/` state and verify skills, and becomes the
  source of truth once it exists.

## Install (in the workspace)

Clone into `~/ebs/projects/claude-work-setup` and run `bash bootstrap.sh`. The first run seeds
`~/ebs/.claude/overlay.env` from `overlay.env.example` and continues with defaults; edit the
overlay (enterprise GitHub host, PyPI mirror, CDP endpoint, workspace mode), then run bootstrap
again. Bootstrap links `claude/` files into `~/ebs/.claude` one by one (platform files stay
untouched), renders `settings.json` from `claude/settings.json.tmpl`, installs tools into
`~/ebs/tools` through the internal mirrors, and wires each project. It is safe to re-run after
every workspace rebuild. `docs/POD-CHECKLIST.md` is the first-run checklist.

## Layout

| path | what |
|---|---|
| `bootstrap.sh`, `overlay.env.example` | workspace bootstrap and the overlay template |
| `claude/CLAUDE.md` | global standards for TypeScript/React, Spring Boot, Python, Terraform, Snowflake |
| `claude/settings.json.tmpl` | deny list, hooks, plugins; `__DEFAULT_MODE__` set from the overlay |
| `claude/hooks/` | PreToolUse guards, Teams notification, shared `lib.sh` |
| `claude/commands/` | `/checkpoint`, `/resume`, `/dispatch`, `/review-pr` |
| `claude/skills/humanizer/` | vendored humanizer skill |
| `claude/statusline.sh` | two-line statusline |
| `protocol/` | `BUILD-PROTOCOL.md` and templates for programmes, repos and verify skills |
| `tools/cdp.mjs` | zero-dependency Chrome DevTools Protocol CLI, linked as `cdp` |
| `projects/`, `programmes/` | empty here; filled in the firm fork |
| `tests/` | hook, bootstrap, settings, statusline and CDP tests |

## Adding a project, a verify skill or a programme

- **Project:** create `projects/<repo>/CLAUDE.local.md` from the matching
  `protocol/templates/CLAUDE.local.<stack>.md`, named exactly like the checkout under
  `PROJECTS_DIR`, and re-run bootstrap. It links the file into the checkout and adds it to
  `.git/info/exclude`.
- **Verify skill:** run `/create-verification-skill` inside the app repo, move the output to
  `projects/<repo>/skills/verify-<repo>/`, and re-run bootstrap to link it into
  `~/ebs/.claude/skills/`. `protocol/templates/verify-skill/` shows the expected shape.
- **Programme:** copy `protocol/templates/` into `programmes/<name>/` (PLAN.md, ROADMAP.md,
  SESSION-RESUME.md, BOARD.json) and add `contracts/` and `verify/` as tasks need them.

## Tests

`tests/run.sh` runs every hook test with fake tool-input JSON, the bootstrap test against a
throwaway HOME, the settings and statusline tests, and the CDP test against headless Chrome when
one is installed (skipped otherwise). It also runs shellcheck, checks that scripts are
executable, rejects lines over 100 characters and embedded git repositories. Requires bash 4+,
jq, git, shellcheck and Node 22.

## Attribution

- [superpowers](https://github.com/obra/superpowers-marketplace) by Jesse Vincent (MIT),
  installed as a plugin.
- [pstack](https://github.com/cursor/plugins) by Lauren Tan (MIT), installed through the Claude
  Code port [pstack-claude](https://github.com/hadifarnoud/pstack-claude) (MIT); its
  `technical-writing` and verification-skill workflows are cited throughout the protocol.
- [humanizer](https://github.com/blader/humanizer) by Siqi Chen (MIT), vendored in
  `claude/skills/humanizer/` with its LICENSE.
- `modern-python` and `gh-cli` from [Trail of Bits skills](https://github.com/trailofbits/skills)
  (CC-BY-SA-4.0), installed as plugins.
