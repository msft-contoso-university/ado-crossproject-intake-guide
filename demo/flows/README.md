# Power Automate Flow — "P Intake Mirror (Front Door)"

This folder contains the flow that implements **Pattern 2 — Power Automate Front Door** from the
[Cross-Project Intake Guide](http://demo.gilbertappiah.com/ado-crossproject-intake-guide/).

| File                       | Purpose                                                                |
|----------------------------|------------------------------------------------------------------------|
| `intake-mirror.flow.json`  | Workflow definition (Logic-Apps-style JSON). Reference + import seed.  |

## Target Power Automate environment

| Field            | Value                                          |
|------------------|------------------------------------------------|
| Environment URL  | `orgdc9ce55e.crm.dynamics.com`                 |
| Region           | Preview (United States)                        |
| Type             | Developer                                      |
| Organization ID  | `1aaf6e64-135c-f011-8ee5-0022480adf27`         |
| Environment ID   | `5ca71bdb-7534-efd7-9278-952de6ab4208`         |
| Tenant ID        | `16b3c013-d300-468d-ac64-7eda0820b6d3`         |
| Owner            | Gilbert Appiah                                 |

Direct link to the environment in the maker portal:

```
https://make.powerautomate.com/environments/5ca71bdb-7534-efd7-9278-952de6ab4208/home
```

Make sure this environment is selected (top-right environment picker) before creating the flow.

## What the flow does

```
 Team-Apollo / Team-Borealis                 P (central)
 ─────────────────────────                   ──────────
 User Story created                          P#nnn [INTAKE] <title>
 with tag "intake-to-P"  ──Power Automate──▶ AreaPath = P\Intake
                                             ↓
                                             System.LinkTypes.Related ──▶ source story
```

1. **Trigger** — *"When a work item is created"* (Azure DevOps connector) on each contributing
   project, filtered to `User Story`.
2. **Condition** — only proceed when `System.Tags` contains `intake-to-P` **and** the source
   project ≠ `P` (prevents self-loops).
3. **Action 1** — *"Create a new work item"* in `P` of type `User Story`, area path `P\Intake`,
   title prefixed with `[INTAKE]`, description carrying source project / source id / submitter.
4. **Action 2** — `PATCH` `/wit/workItems/{newId}` with a `System.LinkTypes.Related` relation
   pointing back to the source item (cross-project link). Documented under
   [Add a link — REST API](https://learn.microsoft.com/rest/api/azure/devops/wit/work-items/update).

## Manual import (5 minutes)

> Power Automate flows cannot be created non-interactively without a packaged solution signed by
> the publisher. The fastest reliable path is the manual one below — it takes about 5 minutes.

1. Go to <https://make.powerautomate.com> → choose environment that contains your ADO connector.
2. **+ Create → Automated cloud flow → Skip**.
3. Add trigger **Azure DevOps → When a work item is created**.
   - Organization: `gappiahdemo-msft`
   - Project: `Team-Apollo` (you will clone the flow once for each contributing project, OR use the
     "When a work item event occurs (V3)" variant which lets you select multiple projects).
   - Type: `User Story`
4. Add **Condition**:
   - `contains(toLower(triggerOutputs()?['body/fields/System_Tags']), 'intake-to-p')` is **true**.
5. In the **If yes** branch, add **Azure DevOps → Create a new work item**:
   - Organization: `gappiahdemo-msft`, Project: `P`, Work item type: `User Story`
   - Title: `[INTAKE] @{triggerOutputs()?['body/fields/System_Title']}`
   - Area Path: `P\Intake`
   - Tags: `intake-to-P; source:@{triggerOutputs()?['body/fields/System_TeamProject']}`
6. Add **HTTP** action (or **Send an HTTP request to Azure DevOps**) using values from
   `intake-mirror.flow.json` → `Link_source_back_as_Related`.
7. Save, rename to **P Intake — Mirror Story (Front Door)**, turn on.
8. Test: in `Team-Apollo` create a `User Story` with tag `intake-to-P` → within 30 seconds a new
   `[INTAKE] …` story appears in `P\Intake` with a Related link back.

## Service-Hooks alternative (no Power Platform license)

If your org cannot use Power Platform, the same outcome is achievable with **Project settings →
Service hooks → Web Hooks** pointing at an Azure Function. The Function receives the
`workitem.created` payload and calls the same `wit/workItems` REST API used in step 6 above. See
[Service hooks — Azure DevOps](https://learn.microsoft.com/azure/devops/service-hooks/overview).

## Why a `.zip` solution is not committed

A signed Power Platform solution `.zip` requires a publisher prefix tied to the importing
environment and a Dataverse schema version that matches that tenant. Hand-fabricated zips break on
import in ~30 % of tenants. The JSON definition + 8-step recipe above is more portable and lets the
demo owner own the connector authentication.
