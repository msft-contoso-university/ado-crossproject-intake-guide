# Copilot Instructions

## Repository purpose

This repository publishes an enterprise-grade solution design guide for cross-project work intake in Azure DevOps. The primary deliverable is `index.html`, rendered on GitHub Pages.

## Research methodology

All recommendations in this guide must be grounded in **Microsoft Learn** documentation. To maintain that bar, this repository installs the official **MicrosoftDocs `azure-devops` agent skill**.

- **Skill location**: `.github/skills/azure-devops/SKILL.md`
- **Skill source**: <https://github.com/MicrosoftDocs/Agent-Skills/tree/main/skills/azure-devops>

When extending or updating this guide, Copilot should:

1. **Consult `.github/skills/azure-devops/SKILL.md` first** to locate the authoritative Microsoft Learn URL for the topic (project structure, permissions, process customization, auditing, licensing, linking, etc.).
2. **Fetch the referenced Microsoft Learn page** (via `fetch_webpage` or `mcp_microsoftdocs:microsoft_docs_fetch`) before making any new claim in `index.html` or `README.md`.
3. **Cite the source** inline in the HTML with an `<a href="https://learn.microsoft.com/...">` link.
4. **Preserve the enterprise lens**: every recommendation should address governance, auditability, least-privilege access, scalability, and compatibility with existing ALM investments (e.g., 7Pace).

## Content conventions

- The target organization is referenced generically as the **P project** inside a fictitious organization **contoso**. Do not introduce real customer names.
- Use ASCII diagrams with `─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼` for architecture visuals inside `<pre class="ascii-diagram">`.
- Keep Primer CSS classes (`Label`, `container-xl`, etc.) and the existing dark-hero styling consistent.
- Do not commit customer identifiers, PII, or secrets.

## Skill refresh

To refresh the skill content:

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MicrosoftDocs/Agent-Skills/main/skills/azure-devops/SKILL.md' `
                  -OutFile '.github/skills/azure-devops/SKILL.md' -UseBasicParsing
```
