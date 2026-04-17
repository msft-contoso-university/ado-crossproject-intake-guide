# Azure DevOps Cross-Project Intake Guide

An enterprise-grade solution design guide for handling cross-project User Story intake in Azure DevOps — letting IT and business teams in other Azure DevOps projects submit work into a central program-office project (referenced here as the **P project** inside the **contoso** organization) while preserving 7Pace time tracking, audit compliance, and full traceability.

**Live site**: <http://demo.gilbertappiah.com/ado-crossproject-intake-guide/>
**Default Pages URL**: <https://msft-contoso-university.github.io/ado-crossproject-intake-guide/>

---

## What's in the guide

The guide (`index.html`) walks through:

1. **Problem & enterprise constraints** — why standard Azure DevOps doesn't do cross-project intake out of the box.
2. **Three validated patterns**
   - **Pattern 1** — Intake Area Path inside the P project with a pinned cross-project query.
   - **Pattern 2** — Microsoft Form + Power Automate flow that creates and links work items through a dedicated service account.
   - **Pattern 3** — Native "Move work item to another project" as a lightweight fallback.
3. **Pattern comparison matrix** across setup cost, submitter UX, governance, 7Pace compatibility, and scale.
4. **Implementation plan** — concrete Sprint 1 and Sprint 2 actions.
5. **Permissions matrix** — object-level, project-level, and collection-level permissions that make each pattern work with least privilege.
6. **Enterprise Governance & Compliance** — audit logging (Entra-backed orgs, 90-day retention, SIEM streaming), identity scoping, and SLA enforcement.
7. **7Pace compatibility notes**.
8. **FAQ + references** to official Microsoft Learn pages.

---

## Research methodology — skill-assisted

Because this is an enterprise recommendation, every claim must be traceable to an authoritative Microsoft source. To achieve that, this repository installs the official **MicrosoftDocs `azure-devops` agent skill** from the [Agent-Skills repo](https://github.com/MicrosoftDocs/Agent-Skills/tree/main/skills/azure-devops).

- **Skill location in this repo**: [`.github/skills/azure-devops/SKILL.md`](./.github/skills/azure-devops/SKILL.md)
- **What the skill provides**: A curated index of 200+ Microsoft Learn pages across Security, Configuration, Decision-Making, Architecture & Design Patterns, Limits & Quotas, and Integrations for Azure DevOps.
- **How it's used**: GitHub Copilot (or any MCP-aware AI assistant) reads the skill to locate the correct Microsoft Learn URL for a topic, then fetches the live page before making a recommendation.

Copilot behavior is encoded in [`.github/copilot-instructions.md`](./.github/copilot-instructions.md).

### Agent-driven workflow — hve-core

Alongside the Microsoft Learn skill, this work uses the **hve-core** agent pack from <https://github.com/microsoft/hve-core/tree/main/plugins/hve-core/agents/hve-core> to structure the research → plan → implement → review loop. The following agents (installed from that link) are invoked in sequence:

| Agent | Role in this project |
|---|---|
| **Task Researcher** | Consults the `azure-devops` skill, fetches Microsoft Learn pages, and produces dated research documents under `.copilot-tracking/research/` — e.g. the gap analysis at `.copilot-tracking/research/2026-04-17/cross-project-intake-gap-analysis-research.md`. |
| **Task Planner** | Converts research findings into a concrete implementation plan (section additions, new diagrams, new references) with prioritized, actionable steps. |
| **Task Implementer** | Applies the plan to `index.html`, `README.md`, and supporting files, preserving enterprise conventions and citation discipline. |
| **Reviewer(s)** | Validates that every new claim is backed by a Microsoft Learn citation, the enterprise lens is preserved, and no customer identifiers leaked. |

This mirrors Microsoft's own high-value engineering practice of separating research, planning, implementation, and review — giving the solution design guide an auditable authoring chain that matches the auditability story it recommends to the customer.

### Why this matters for enterprise customers

- **Defensible recommendations**: Every pattern, permission, and caveat in the guide maps to a cited Microsoft Learn article.
- **No hallucinated APIs or permissions**: Claims like *"moving a work item requires the Inherited process"* and *"child work items do not move with the parent"* come straight from the official docs and are linked inline.
- **Repeatable**: Other solution architects can clone this repo, refresh the skill, and generate equally grounded guides for adjacent topics.

### Refresh the skill

```powershell
Invoke-WebRequest `
  -Uri 'https://raw.githubusercontent.com/MicrosoftDocs/Agent-Skills/main/skills/azure-devops/SKILL.md' `
  -OutFile '.github/skills/azure-devops/SKILL.md' `
  -UseBasicParsing
```

---

## Local preview

The guide is a single self-contained HTML file with Primer CSS served from the official CDN. To preview locally:

```powershell
Start-Process index.html
```

Or serve the folder over HTTP:

```powershell
python -m http.server 8080
# then open http://localhost:8080/
```

---

## Repository layout

```
.
├── .github/
│   ├── copilot-instructions.md       # How Copilot should use the skill
│   └── skills/
│       └── azure-devops/
│           └── SKILL.md              # MicrosoftDocs azure-devops skill
├── .gitignore
├── README.md                         # This file
└── index.html                        # The guide (published to Pages)
```

---

## Contributing

When proposing a change to the guide:

1. Identify the topic in the skill index (`.github/skills/azure-devops/SKILL.md`).
2. Fetch the cited Microsoft Learn URL and confirm the claim.
3. Add an inline `<a>` reference in `index.html` pointing to `learn.microsoft.com/...`.
4. Keep the enterprise lens — governance, auditability, least privilege, scalability.
5. Do not introduce customer identifiers. Use the generic `P` project inside `contoso`.

---

## License & attribution

- Microsoft Learn content is © Microsoft and referenced under fair-use citation.
- The `azure-devops` agent skill is published by Microsoft at [MicrosoftDocs/Agent-Skills](https://github.com/MicrosoftDocs/Agent-Skills) under its own license.
- Solution design narrative in `index.html` is provided as-is for reference.
