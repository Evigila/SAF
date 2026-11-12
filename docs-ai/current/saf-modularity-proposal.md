# SAF configuration and rule organization

## Status and retained decisions

This report describes the formal SAF 2.0.0 release target's configuration/policy contract, incorporating the earlier configuration/runtime feature and recovery fixes. Configuration uses schema 2, handler protocol 3, and config support version 2; release and lock schemas remain 1. The earlier exploratory proposal remains [archived as superseded](1_archived/2026-11-12_saf-modularity-proposal.md), not active policy. The [generality review](saf-generality-review.md) retains the four diagnoses from checkpoint `47785cf9bc7f0ab268817f512891e3f728cbead9` as history, separately from current configuration. Fresh 2.0.0 fixture runs passed in Windows PowerShell 5.1 and existing PowerShell 7, as recorded below; the earlier 3.0.0 label remains unpublished preparation history. This ordinary report retains its descriptive name without the template `1_` prefix.

`AGENTS.md` remains the sole project instruction entry point. `SAF.config.json` is typed data consumed through that entry point and existing handlers/skills, not another policy authority, a model adapter, or a general rule engine. No extra instruction entry point is introduced.

## Fixed shared standards

| Topic | Retained requirement |
| --- | --- |
| Monthly audit | Keep the calendar-month schedule. Inspect SAF artifacts, metadata/skill formats, required files/directories, config validity, and framework integrity; do not review business source or project architecture/dependency facts |
| Architecture document | Describe key file/directory/project responsibilities and dependency direction; no exhaustive maintained-file tree |
| Language | English remains mandatory for SAF instructions and AI-maintained documents/records; no configurable language key |
| Root scripts | Only `origin.bat`, `local.bat`, and `debug.bat` are allowed as AI-created root scripts; source-only bootstrap remains `scripts/init.ps1` |
| Authority and integrity | Configuration never grants task authorization or disables ownership, path/hash validation, safe state coordination, or protection under Force |
| Rule entry point | `AGENTS.md` routes shared standards, typed project restrictions, skills, and project facts; no additional policy entry |
| Verification | Run tests appropriate to implementation changes within existing task authorization and explicit user limits; no automated-test opt-out field |
| Git history | Ask before a commit unless already authorized; never delete or rewrite existing commits. Configuration affects commit presentation only |

Project-content investigation remains task-scoped. Format-valid architecture/dependency seeds satisfy SAF structure without certifying their facts. The compatible `audit-project-docs` name remains, with SAF-structure scope and shared `Set-SafState` audit-only completion.

## Configuration that has actual readers

`SAF.config.json` uses schema version 2. `Resolve-SafConfig -Root` reads bytes once for parsing/hash evidence, supplies defaults, and validates known fields/types/enums and protected path kinds. Object roots are required before parser enumeration; writes check targets plus missing ancestors, and bounded recovery tracks committed mutations. Source inspection does not establish complete enforcement or functional success; see the [generality review](saf-generality-review.md). Agent workflows consume their documented values separately; scripts do not launch an Agent or enforce activity in an unrelated external session.

| Field group | Consumer and effect |
| --- | --- |
| `origin.repository/ref` | Origin selects explicit values, then configured defaults, then recorded installation/bootstrap provenance; missing repository errors and a still-missing ref defaults to `main` |
| `project.protectedPaths` | Exact relative files or trailing-slash directory prefixes; handler writes reject protected targets, and Agent work preserves them absent explicit task authority |
| `project.verification.computerUse` | `deny` by default, or `inherit`; Agent verification preference, never tool permission. Applicable explicit user instructions take precedence |
| `project.ui.framework` | Nonempty UI-guidance string, default `Material Design 3`; does not authorize adopting or installing a UI library |
| `project.commit.style` | Nonempty presentation string, default `follow-history`; Agent follows the established repository commit pattern |
| `project.commit.initialStyle` | Nonempty fallback presentation string, default `english-imperative`; used when no established commit pattern applies |

Default consumer bytes contain only `{ "schemaVersion": 2 }`. Resolver defaults have no source or additional protected paths, deny Computer Use testing, prefer `Material Design 3`, and use commit styles `follow-history`/`english-imperative`. Source-project config adds its current repository/main and protected README pair while declaring those presentation/testing defaults explicitly. No source-specific paths or origin values are copied into consumers.

Schema 1 and its project-name, automated-test authorization, delivery-approval, and record-time-zone fields are historical. Schema 2 rejects them as unknown fields. Existing local preparation configuration requires an explicit migration before the current SAF 2.0.0 bootstrap; initialization preserves old bytes instead of replacing them. Record time zones follow applicable shared/session guidance and are no longer a project configuration setting. Operational timestamps remain UTC.

No config keys control English, audit cadence/scope, root-script rules, core ownership/integrity, arbitrary module paths, shell expressions, or model execution. Existing explicit instructions and authorization take precedence; configuration may narrow available work, never expand authority.

## Ownership and update protection

- `SAF.json`: release-owned payload/version/compatibility manifest.
- `SAF.config.json`: project-owned seed-only values. Preserve existing bytes under update, Force, bootstrap repair, and memory compression; include it in scoped recovery.
- `SAF.lock.json`: observed bootstrap/installation/audit state with separate ownership and shared section writes.
- `AGENTS.md` and `common/`: existing instruction routing and effective standards, still subject to managed conflict detection.
- `docs-ai/current/`: evidence-based project facts and records, separately maintained during relevant tasks.

The source release declares `handlerProtocolVersion: 3` and `configSupportVersion: 2`, with a minimum framework version of 2.0.0. Bootstrap verifies declared config support before loading source helpers, preventing an initial deployment from silently using a controller that ignores project restrictions. Old configuration must first be migrated to schema 2; compatible bootstrap then refreshes handlers. Updating config does not authorize replacing project data or refresh structural-audit completion.

## Unified runtime storage

Runtime data now belongs under `.agents/backup/`, `.agents/saf_log/`, and `.agents/operation.lock`, alongside but distinct from maintained skill packages under `.agents/skills/`. Keep runtime storage ignored, scoped out of release payloads, and excluded from recursive backups. Never treat all of `.agents/` as a cache.

Bootstrap, non-Check origin operations, and local operations coordinate preservation/migration of legacy `.agent/` runtime data. Verified identical copies may be reused; a differing backup collision stops with both retained, while differing old logs receive a content-hash-suffixed location under `.agents/saf_log/legacy/`. Old sources are removed only after copy verification, with old/new operation coordination retained. Check only writes a current `.agents/saf_log/` record and does not migrate runtime. Operational timestamps remain UTC.

## Verification boundaries

The [scope correction](1_changelogs/2026-11-12_155517_saf-audit-scope.md) and [bootstrap relocation](1_changelogs/2026-11-12_160523_bootstrap-under-scripts.md) records, prepared under the unpublished 2.0.1 label, retain their original results, including the historical 34-case 5.1 run. Those runs do not establish the later config/protocol/migration behavior or final 2.0.0-target verification.

The earlier feature prepared under the unpublished 2.1.0 label passed 68 user-authorized native PowerShell 5.1 integration checks, plus a focused protected-empty-backup follow-up. Its PowerShell 5.1/7 parsing and manifest/hash validation passed. See the [configuration/storage record](1_changelogs/2026-11-12_163705_saf-project-configuration.md) for that coverage. The source legacy log was then byte-verified after migration without changing framework state or skills. Agent workflow preferences, live remote initialization, actual Downloads redirection, interactive menus, and arbitrary concurrent edits still need manual acceptance; the old test result does not certify those behaviors or the new fixes.

Recorded on 2026-11-13 at 11:36, America/Sao_Paulo (UTC-03:00): the coordinator completed fresh isolated SAF 2.0.0 runs under ordinary user TEMP. Windows PowerShell 5.1 passed all 152 checks, exit 0; existing PowerShell 7 passed all 148 checks, exit 0. Four Desktop-only fallback checks explain the difference. Both runs covered schema 2, current defaults/UI/commit values, removed-field rejection, and R1-R4 regressions. Earlier 3.0.0-label runs remain unpublished preparation history, separate from these fresh results. No Computer Use, live network initialization, or other-platform runtime test was performed; fresh-session Agent behavior remains separate acceptance.

The 68 earlier checks and focused follow-up remain historical unpublished-preparation evidence. The [fix record](1_changelogs/2026-11-13_084811_config-recovery-fixes.md) preserves repair history; the [regression checklist](saf-configuration-regression-checklist.md) records fresh 2.0.0 results and repeatable checks. Recovery is best effort under both original/current protections and cannot guarantee isolation from arbitrary external edits or power loss.
