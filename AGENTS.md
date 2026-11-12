# Project instruction router

First inspect `SAF.lock.json` and the effective release in `SAF.json`, then follow the [audit gate](docs-ai/common/rules.md#audit-gate). `SKIP_AUDIT` skips only the full documentation audit; it never skips this router or applicable task rules.

## Read for the task

| Task or trigger | Required reading |
| --- | --- |
| Every project task | [Task boundaries](docs-ai/common/rules.md#task-boundaries) and [Document ownership](docs-ai/common/rules.md#document-ownership) |
| Code, project, namespace, or public API changes | Relevant [code standards](docs-ai/common/codedesign.md), affected source, and repository configuration |
| UI or UX work | [UIUX.md](docs-ai/common/UIUX.md), then the project's actual components, styles, contracts, and host usage |
| Repository structure or architecture | [1_architecture.md](docs-ai/current/1_architecture.md), then affected source/configuration |
| Project scripts, debugging, data resets, or publication | [Project scripts and entry points](docs-ai/common/rules.md#project-scripts-and-entry-points), then affected scripts and configuration |
| Dependencies, assets, build, or deployment | [External dependencies](docs-ai/common/rules.md#external-dependencies), [1_dependency.md](docs-ai/current/1_dependency.md), declarations, and resolved evidence |
| Documentation creation, restructuring, or audit | [Documentation contract](docs-ai/common/rules.md#documentation-contract) and [Full documentation audit](docs-ai/common/rules.md#full-documentation-audit) |
| Implementation, testing, or delivery | [Implementation and verification](docs-ai/common/rules.md#implementation-and-verification) and [Delivery and records](docs-ai/common/rules.md#delivery-and-records) |
| A decision depends on history | Only relevant records in `docs-ai/current/1_changelogs/`, `1_bugreports/`, or `1_archived/` |
| The audit gate requires an audit | [audit-project-docs](.agents/skills/audit-project-docs/SKILL.md) |
| SAF initialization, version checks, or updates | [sync-saf](.agents/skills/sync-saf/SKILL.md), [synchronization rules](docs-ai/common/rules.md#framework-synchronization), and source/local metadata |
| Semantic consolidation of AI project memory | [compress-saf](.agents/skills/compress-saf/SKILL.md) and [Memory compression](docs-ai/common/rules.md#memory-compression) |
| Local backup, archive cleanup, or archive ignore | [Local maintenance](docs-ai/common/rules.md#local-maintenance) and affected local scripts |

Add reading when scope changes. Read relevant sections and affected subtrees; do not load all history or dependencies for an unrelated task. Reuse unchanged material already read during the task. Read a project skill's `SKILL.md` directly when native discovery is unavailable.

## Where instructions and facts belong

| Location | Responsibility |
| --- | --- |
| `AGENTS.md` | Instruction entry point and reading routes |
| `docs-ai/common/` | Effective shared code, UI, workflow, and documentation standards |
| `.agents/skills/` | Reusable workflows; mandatory policies remain in this router and `common/` |
| `docs-ai/current/1_architecture.md` | Verified repository tree and architecture |
| `docs-ai/current/1_dependency.md` | Verified dependency inventory |
| `docs-ai/current/1_changelogs/` | Append-only change records |
| `docs-ai/current/1_bugreports/` | Diagnosis, fixes, and regression evidence |
| `docs-ai/current/1_archived/` | Superseded or abandoned designs; no authority over new work |
| `SAF.json` | Release-owned version and payload inventory |
| `SAF.lock.json` | Project-owned bootstrap/installation provenance and independent audit state |
| `.agent/backup/`, `.agent/saf_log/` | Local recovery snapshots and logs, distinct from memory and skill discovery |

Keep this router and `docs-ai/` under version control. Preserve project facts and audit evidence during updates. New consumers must inspect their own facts and start unaudited; never import the source repository's completed audit. Active standards contain no dated approval history or superseded policy.

Follow the runtime's effective instruction hierarchy and the user's authorized scope. This file does not override higher-priority instructions. Resolve conflicts under [Task boundaries](docs-ai/common/rules.md#task-boundaries).