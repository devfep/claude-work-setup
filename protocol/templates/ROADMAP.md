# Roadmap — <programme>

Tasks execute under `protocol/BUILD-PROTOCOL.md`. One task, one repo, one fresh lane.

- [ ] **TASK-001** jira: ABC-100 · repo: workflow · stack: contract · after: —
  Write `contracts/endpoint-registration.md`: request/response shape, validation rules, error
  codes.
  Verify: `test -s contracts/endpoint-registration.md &&
  grep -q '## Response' contracts/endpoint-registration.md`
  Done: both the UI task and the job task can be briefed from this file alone.
- [ ] **TASK-002** jira: ABC-101 · repo: app-admin · stack: node · after: TASK-001
  Registration form posts the contract's payload and shows the server's validation errors inline.
  Feature map: `features/endpoint-registration.md`
  Verify: `vitest run src/registration` passes and `verify-app-admin` drives an invalid submit and
  captures the inline error.
  Done: an engineer registers an endpoint and sees a confirmation with its id.
