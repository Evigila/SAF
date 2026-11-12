---
name: audit-project-docs
description: Perform a full project documentation audit when requested or required by the AGENTS audit gate. Verify current architecture and dependencies, repair authorized gaps, and update audit state only after completion. Do not run for an unrelated task with a current, valid audit state.
---

# Audit project documentation

1. Resolve the root. Read `AGENTS.md`, `SAF.lock.json`, and the audit gate/documentation contract in [rules.md](../../../docs-ai/common/rules.md). Read `SAF.json` for the effective version. Stop this workflow if the gate returns `SKIP_AUDIT` and no full audit was requested; continue the original task. Audit is an Agent skill, not a `local.bat` command.
2. Check required paths, ownership, and substantive content. Validate skill packages through `SKILL.md`. The source repository may have null bootstrap/installation sections; do not invent a consumer installation or copy central audit evidence.
3. Verify the complete tree in `docs-ai/current/1_architecture.md` from maintained source/configuration, using the documented exclusions. Check modules, applications, references, and runtime/resource boundaries.
4. Verify `1_dependency.md` from declarations and resolution evidence, including transitive packages where applicable. Distinguish declared/observed versions and mark unknowns.
5. Consolidate missing facts. Reuse supplied evidence and authorization; ask once only for unavailable information. Repair authorized AI documents in English. Preserve human content and history.
6. Check changes against effective standards and record durable repairs when needed. Do not use templates/placeholders as completion evidence.
7. Leave completion unchanged while essential gaps remain. Otherwise create an audit object with effective `auditedFrameworkVersion`, actual UTC `lastCompletedAtUtc`, and preserved/applicable `lastMissingMaterialAskedAtUtc`. Dot-source `<root>/scripts/saf-core.ps1` and call `Set-SafState -Root <root> -Section audit -Value <audit-object>`. This merges only audit under the shared operation lock. Never directly rewrite the full lock or overwrite bootstrap/installation. A missing/incompatible helper is unresolved, not permission to bypass coordination.
8. Report scope, repairs, actual verification, and unresolved facts; return to the original task. Audit does not replace its implementation or testing.

Use shared standards as authority. Do not duplicate policy or install inspection dependencies. Follow static-only/manual-testing limits. A documentation audit does not prove functional tests passed; ordinary/partial inspections must not refresh completion.