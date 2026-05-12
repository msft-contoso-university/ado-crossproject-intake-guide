# Live Demo — Cross-Project Intake in `gappiahdemo-msft`

A working ADO instantiation of the patterns described in
[../index.html](../index.html) and narrated by [../walkthrough.html](../walkthrough.html).

| Component                | Where it lives                                                                       |
|--------------------------|--------------------------------------------------------------------------------------|
| Central intake project   | <https://dev.azure.com/gappiahdemo-msft/P>                                           |
| Contributing team #1     | <https://dev.azure.com/gappiahdemo-msft/Team-Apollo>                                 |
| Contributing team #2     | <https://dev.azure.com/gappiahdemo-msft/Team-Borealis>                               |
| Inherited process        | `P-Intake` (parent: Agile)                                                           |
| Power Automate flow      | [flows/README.md](flows/README.md) — manual 5-min import                             |

## What you get after `provision.ps1`

* 3 ADO projects on the **`P-Intake`** inherited process.
* In **`P`**: area paths `Intake`, `Triage`, `Programs/Apollo`, `Programs/Borealis`; three
  rolling sprints; three saved queries under `Shared Queries/P-Intake/`.
* 4 seeded `[INTAKE]` User Stories in `P\Intake` (or `P\Triage`).
* 4 matching source stories in `Team-Apollo` / `Team-Borealis`, each linked back to its mirror in
  `P` via `System.LinkTypes.Related` — visualizing the cross-project linkage demonstrated in
  Pattern 1 + Pattern 2 of the guide.

## Run

```powershell
# Provision (idempotent; safe to re-run)
pwsh ./demo/provision.ps1

# Tear down (asks for confirmation; deletes 3 projects + the inherited process)
pwsh ./demo/teardown.ps1 -Confirm
```

## 5-minute customer demo script (aligned to walkthrough.html scenes)

| Scene in walkthrough             | Click in ADO                                                                              |
|----------------------------------|-------------------------------------------------------------------------------------------|
| 1. Problem                       | Open `Team-Apollo` and `Team-Borealis` boards side by side — show two disconnected silos. |
| 2. Recommended Solution diagram  | Switch to `index.html` (or stay on walkthrough scene 2) — narrate the SVG architecture.   |
| 3. Pattern 1 — Intake area       | `P` → Boards → Backlogs → filter by Area Path `P\Intake` → show 4 seeded items.           |
| 4. Pattern 2 — Front door        | In `Team-Apollo`, create a User Story tagged `intake-to-P` → flip to `P\Intake`, item is mirrored within ~30s. |
| 5. Triage                        | `P` → Boards → Queries → `Shared Queries/P-Intake/Intake - Awaiting Triage`. Move 1 item to `Programs\Apollo` to "accept". |
| 6. Cross-project linkage         | Open any `[INTAKE]` story → Links tab → click the Related link → opens the source story in `Team-Apollo`. |
| 7. Reporting                     | Show `Cross-Project Accepted Stories` query → mention OData / Power BI funnel page.       |

## Customizing

`provision.ps1` accepts overrides:

```powershell
pwsh ./demo/provision.ps1 `
    -Organization 'https://dev.azure.com/your-org/' `
    -CentralProject 'PMO' `
    -TeamProjects @('Web','Mobile','Data') `
    -ProcessName 'PMO-Intake'
```

## Why these choices

* **`Related` (not `Remote Related`)** — Remote Related links target items in *different ADO
  organizations*. Within a single org, `System.LinkTypes.Related` traverses cross-project and is
  what the guide recommends for Pattern 1.
  [Link types reference](https://learn.microsoft.com/azure/devops/boards/queries/link-type-reference).
* **Inherited process, not custom** — preserves upgradability to the Agile parent.
  [Customize an inherited process](https://learn.microsoft.com/azure/devops/organizations/settings/work/inheritance-process-model).
* **Tag-driven trigger** — keeps the Power Automate flow stateless; tag visibility is auditable.

## Reset

`teardown.ps1` deletes the three projects and the inherited process. Hard delete; no recovery.
