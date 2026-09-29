# Local workflow rules for this repo (not committed; linked by bootstrap)

Stack: terraform. Root modules: <paths>. Base branch: develop.
Format: `terraform fmt -check -recursive`. Validate: `terraform init -backend=false &&
terraform validate`. Lint: `tflint` (if installed).
Plan: `aws-switch <sandbox account alias>`, then
`terraform plan -var-file=<sandbox tfvars> -out=<evidence>/plan.tfplan` and
`terraform show -no-color <evidence>/plan.tfplan > <evidence>/plan.txt`.
Intended resources for a task are listed in its Done line; the plan must touch nothing else.
Never `terraform apply` or `destroy`.
Evidence path: programmes/<programme>/verify/<JIRA>/.
Repo-specific notes: <anything the team's CLAUDE.md does not say>.
