# Pod checklist (run once per workspace, one line at a time)

Type each line by hand in the pod; the expected result is after the arrow.

1. `git clone https://github.com/<you>/claude-work-setup ~/ebs/projects/claude-work-setup`
   → clone succeeds.
2. `bash ~/ebs/projects/claude-work-setup/bootstrap.sh` → seeds the overlay and continues with
   defaults; edit it (`vi ~/ebs/.claude/overlay.env`: GH_HOST, PYPI_INDEX_URL, CDP_URL,
   WORKSPACE_MODE), then re-run.
3. `bash ~/ebs/projects/claude-work-setup/bootstrap.sh` → "done"; note any `warn:` lines (tools
   the mirror does not serve).
3a. For `rtk`: set `RTK_VENDORED_REPO` in the overlay to your vendored clone's git URL. Rust
    comes from the platform's `rustup-init` (on PATH; the managed `toolchain install rustup`
    entry installs nothing, and release downloads from GitHub are refused): run `rustup-init`,
    accept the defaults, open a new shell, confirm `cargo --version` is 1.91 or newer, then
    re-run bootstrap. The first build takes several minutes; later runs skip it because
    `~/ebs/tools/bin/rtk` exists. After a workspace rebuild, run `rustup-init` again first.
4. `source ~/ebs/.shellrc && uv --version && prek --version && shellcheck --version | head -2 &&
   cdp doctor` → versions print; doctor shows Chrome.
5. Plugins come only from the firm's internal marketplace. Declare it and the approved plugins in
   `~/ebs/.claude/settings.firm.json` (same keys as settings.json: `extraKnownMarketplaces`,
   `enabledPlugins`), re-run bootstrap, start a session, then
   `DEVSPACE_CLAUDE_LAUNCH=1 /usr/local/libexec/claude-real plugin list` shows them. Skills that
   exist only on public GitHub go through the firm's contribution process first.
6. In a session: `echo hi` via Bash → runs; `rm -rf /tmp/x` → BLOCKED; `git push origin develop`
   in a team repo → BLOCKED; `git commit -m "no key"` in a team repo → BLOCKED. This proves hooks
   run under the policy helper.
7. `export CDP_TARGET=$(cdp new about:blank) && cdp nav 'data:text/html,<button id=b>Go</button>'
   && cdp snapshot && cdp screenshot /tmp/p.png && cdp close $CDP_TARGET` → snapshot lists the
   button; PNG written.
8. `gh auth status` with `GH_HOST` exported → logged in to the enterprise host;
   `gh pr list --repo <org>/<repo> --limit 1` → works.
9. `uv tool list` and `ls ~/ebs/tools/npm/bin` → confirm tflint/stryker/mutmut presence; record
   absences in the protocol's § 3.3 note in the fork.
10. In a session inside an app repo: write the verify skill (`/create-verification-skill` if the
    internal marketplace provides it, else by hand from `protocol/templates/verify-skill/`), put it at
    `~/ebs/projects/claude-work-setup/projects/<repo>/skills/verify-<repo>/` and re-run
    bootstrap → the skill appears in `/skills`.
11. Fork: `git remote rename origin generic && git remote add origin
    http://<ghe>/<you>/claude-work-setup.git && git push -u origin main` (the platform's git
    proxy form applies) → the fork holds main; from here on `/checkpoint` pushes programme state
    to it (the workflow repo is exempt from the protected-branch hook).
