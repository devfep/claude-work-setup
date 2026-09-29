---
name: verify-<repo>
description: Drive <app> the way a user does and capture proof. Use for G4 of any task touching <repo>, or when asked to verify <app> behaviour.
---

# Verify <app>

## Launch
<exact dev command>, ready when <log line or port>. Teardown: <command>. Two instances cannot
share port <n>; use `PORT=<n+1>` for a second.

## Doctor
`cdp doctor && curl -fsS http://localhost:<n>/<health>` — both succeed or the instance is not
worth driving.

## Drive
`export CDP_TARGET=$(cdp new http://localhost:<n>/)`, then `cdp wait '<selector>'`,
`cdp click '<selector>'`, `cdp type '<selector>' '<text>'`, `cdp eval '<js>'`. Prefer ARIA labels
and `data-testid` over coordinates.

## Evidence
Into `programmes/<programme>/verify/<JIRA>/`: `cdp screenshot <step>.png`,
`cdp snapshot > <step>.ax.txt`, `cdp console 3 > console.jsonl`, `cdp network 3 > network.jsonl`,
plus side effects (rows, files, requests) checked the way a user would see them.

## Cleanup
`cdp close $CDP_TARGET`; stop only the server this run started. Evidence survives cleanup.

## Features
See `features/README.md`; one file per feature with the four sections: Sub-features, How to get
to it (user POV), Driving it with verify-<repo>, Gotchas.
