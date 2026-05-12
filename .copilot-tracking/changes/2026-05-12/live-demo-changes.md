<!-- markdownlint-disable-file -->
# Release Changes: Live ADO Demo in `gappiahdemo-msft`

**Related Plan**: cross-project-intake-plan.instructions.md (extension — live demo provisioning cycle)
**Implementation Date**: 2026-05-12
**Org**: https://dev.azure.com/gappiahdemo-msft/

## Summary

Stood up a working Azure DevOps instantiation of the cross-project intake guide in the `gappiahdemo-msft` org so the guide can be demoed end-to-end (not just narrated). Created 3 ADO projects, area paths, iterations, 8 work items with cross-project Related links, and 3 saved queries. Authored idempotent provisioning + teardown scripts plus a Power Automate "Front Door" flow definition + manual-import recipe targeted at the user's Developer Power Platform environment (`orgdc9ce55e.crm.dynamics.com`, env id `5ca71bdb-7534-efd7-9278-952de6ab4208`).

## Changes

### Added

* `demo/provision.ps1` — Idempotent ADO provisioner (CLI + REST). Creates: 3 projects on `Agile` process (`P`, `Team-Apollo`, `Team-Borealis`), 4 area paths in `P` (`Intake`, `Triage`, `Programs/Apollo`, `Programs/Borealis`), 3 rolling 2-week sprints, 4 `[INTAKE]` User Stories in `P\Intake`/`P\Triage`, 4 source User Stories in the team projects, 4 cross-project `System.LinkTypes.Related` links, 3 saved queries under `Shared Queries/P-Intake/`.
* `demo/teardown.ps1` — Reverses the demo. Deletes the 3 projects (with `-Confirm`); skips deleting built-in `Agile` process.
* `demo/flows/intake-mirror.flow.json` — Workflow definition (Logic-Apps schema) for the Power Automate Front Door flow that mirrors tagged stories from contributing projects into `P\Intake` and back-links via `System.LinkTypes.Related`.
* `demo/flows/README.md` — 8-step manual-import recipe targeted at the user's Developer environment (`orgdc9ce55e.crm.dynamics.com`, env id `5ca71bdb-7534-efd7-9278-952de6ab4208`, tenant `16b3c013-d300-468d-ac64-7eda0820b6d3`). Includes a Service Hooks alternative for license-constrained tenants.
* `demo/README.md` — 5-minute customer demo script aligned scene-by-scene to `walkthrough.html`; `provision.ps1` / `teardown.ps1` usage; rationale notes on `Related` vs `Remote Related` and inherited-process choice.

### Modified

* None to `index.html` / `walkthrough.html` / `README.md` / `.github/`. This cycle is purely additive under `demo/`.

### Removed

* None.

## ADO objects created in `gappiahdemo-msft`

| Type        | Name                                          | ID(s)                                                                                                                                |
|-------------|-----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| Project     | `P`                                           | `d1bfe634-45fc-4853-afc1-396974644de8`                                                                                               |
| Project     | `Team-Apollo`                                 | `05f19050-9756-4e39-b906-be1a26804388`                                                                                               |
| Project     | `Team-Borealis`                               | `ec52bfcc-36e3-4590-8f53-fd4bb3c31173`                                                                                               |
| Process     | `Agile` (built-in, reused)                    | `adcc42ab-9882-485e-a3ed-7678f01f66bc`                                                                                               |
| Area paths  | `P\Intake`, `P\Triage`, `P\Programs\Apollo`, `P\Programs\Borealis` | n/a                                                                                                       |
| Iterations  | `P\Sprint-20260511`, `P\Sprint-20260525`, `P\Sprint-20260608` | n/a                                                                                                            |
| Work items  | Intake stories (P)                            | P#424, P#425, P#426, P#427                                                                                                           |
| Work items  | Source stories                                | Team-Apollo#428, Team-Apollo#429, Team-Borealis#430, Team-Borealis#431                                                                |
| Links       | `System.LinkTypes.Related` (cross-project)    | P#424↔Team-Apollo#428, P#425↔Team-Apollo#429, P#426↔Team-Borealis#430, P#427↔Team-Borealis#431                                       |
| Queries     | `Shared Queries/P-Intake/*` in `P`            | `Intake - New (last 7 days)`, `Intake - Awaiting Triage`, `Cross-Project Accepted Stories`                                            |

## Additional or Deviating Changes

* **Process choice**: Switched from a custom inherited `P-Intake` process to the built-in `Agile` process. Reason: the `az devops invoke` Process API surface needed extra headers/route plumbing that wasn't worth the complexity for the demo — area paths + tags + queries + cross-project links already deliver every story beat in `walkthrough.html`. `provision.ps1` accepts `-ProcessName` so a real customer can swap to an inherited process; `teardown.ps1` only deletes inherited processes, never built-in.
* **Area path API**: First two attempts via `az boards area project create --path` failed with "expected to be absolute path" regardless of whether the path was given as `Programs`, `\Programs`, or `\P\Programs`. Final implementation calls `wit/classificationnodes/areas/{parent}` REST directly — works first try.
* **Cross-project linking**: Used `System.LinkTypes.Related` (single-org cross-project), not `System.LinkTypes.Remote.Related` (which is for *cross-organization* links). Documented this distinction in `demo/README.md`.
* **Power Automate flow**: Not auto-imported. A signed solution `.zip` would require publisher prefix + Dataverse schema specific to the importing tenant — fragile. Instead committed the workflow JSON definition + an 8-step manual recipe targeted at the user's exact Developer environment (env id `5ca71bdb-7534-efd7-9278-952de6ab4208`). Estimated import time: ~5 minutes.
* **Initial run errors fixed**:
  - `Ensure-Process` originally used `--area processes` (wrong) — fixed to direct REST `/_apis/work/processes`.
  - `Add-RemoteRelatedLink` originally produced a malformed JSON-Patch body via `ConvertTo-Json` — replaced with a literal JSON-Patch string. The 4 already-created P items (424–427) were patched with their links via a one-shot loop after the fix.
* **Walkthrough/Index untouched**: Per active directive, `walkthrough.html` is read-only; `index.html` was not touched this cycle either since the demo is additive.

## Validation

* `az devops project list` confirms `P`, `Team-Apollo`, `Team-Borealis` present in `gappiahdemo-msft`.
* All 8 work items created (P#424–427, Team-Apollo#428–429, Team-Borealis#430–431).
* All 4 cross-project link PATCH calls returned exit 0.
* All 3 saved queries created under `Shared Queries/P-Intake/` in `P`.
* Sanitization regression (`afni|pmo` case-insensitive) was already at 0 matches; no changes to guide HTML this cycle, so no re-run required.

## Follow-up (2026-05-12 same day) — pre-populated submission links

Power Automate flow creation could not be performed unattended (the Azure DevOps connector requires interactive OAuth consent in the maker portal; `pac` CLI not installed and would not bypass the consent step). To unblock the user's "give me a link to submit" request, added three pre-populated ADO deep-link URLs to `demo/README.md` using the documented `_workitems/create/{type}?[Field.RefName]=value` syntax. URLs pre-fill `System.Tags=intake-to-P` (Team-Apollo, Team-Borealis) and `System.AreaPath=P\Intake` + `System.Tags=intake-to-P` (P direct). Submitter only types title + description.

## Release Summary

* Files affected: 5 added under `demo/`. No edits to existing repo files.
* ADO footprint: 3 projects, 4 area paths, 3 iterations, 8 work items, 4 cross-project links, 3 saved queries.
* Power Automate footprint: pending the user's manual 5-minute import in env `5ca71bdb-7534-efd7-9278-952de6ab4208`.
* Demo entry point: <https://dev.azure.com/gappiahdemo-msft/P>.
* Reset path: `pwsh ./demo/teardown.ps1 -Confirm`.
