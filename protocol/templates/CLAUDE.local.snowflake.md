# Local workflow rules for this repo (not committed; linked by bootstrap)

Stack: snowflake. SQL paths: <paths>. Base branch: develop.
Lint: `sqlfluff lint <paths>` (dialect: <snowflake>, templater: <jinja|dbt|raw>).
Format: `sqlfluff fix --check <paths>`.
Tests: <local runner command, or "none: lint plus review, stated in the PR">.
No connection to a remote database exists from the pod; never attempt one.
Evidence path: programmes/<programme>/verify/<JIRA>/.
Repo-specific notes: <anything the team's CLAUDE.md does not say>.
