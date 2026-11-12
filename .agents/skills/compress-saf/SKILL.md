---
name: compress-saf
description: Consolidate AI project memory under docs-ai/current when the user requests semantic compression, removing repetition and archiving superseded active reports while retaining effective facts and unresolved work.
---

# Consolidate SAF project memory

Read `AGENTS.md` and the [ownership](../../../docs-ai/common/rules.md#document-ownership), [history](../../../docs-ai/common/rules.md#history-and-archives), and [memory compression](../../../docs-ai/common/rules.md#memory-compression) rules. This is an Agent workflow, not `local.bat` functionality or ZIP cleanup.

Identify active reports under `docs-ai/current/` and source evidence needed to distinguish current facts from superseded proposals. Read history only when necessary. Do not infer ownership from prose style. Preserve user constraints, decisions, unresolved issues, compatibility, provenance, verification status, and unfinished work.

Before edits, create a recovery snapshot with `local.bat -backup` and inspect completion. Respect static-only/no-side-effect limits: inspect and propose changes without executing backup/compression, and report it was not performed. Stop document writes if the required recovery snapshot fails.

Consolidate duplicate active prose without weakening required architecture/dependency inventories. Archive an obsolete active report only after its replacement retains useful facts/provenance. Mark archived status, reason, scope, and replacement; repair active references. Keep append-only changelogs and bug evidence intact and in place. Apart from the backup command's documented local recovery/log/ignore maintenance, do not modify human `docs/`, `common/`, source/configuration, dependencies, or lock state as a side effect.

Record a concise dated change entry linking recovery and replacement/archive paths. Verify references, required inventory completeness, retained unresolved work, and scoped diff. Distinguish simplification from facts verified against implementation; do not mark audit completion or claim functional tests passed.

Report consolidation, archiving, unresolved matters, actual checks, recovery references, and skipped work. Do not delete archive contents or commit/push without authorization.
