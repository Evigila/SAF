# SAF architecture and repository tree

## Inventory scope

This is the SAF 2.0.0 central source inventory. The tree includes every maintained source/configuration file outside documentation. Exclusions: `docs/**` and `docs-ai/**` (documentation), `.git/**` (Git internals), `.agent/backup/**` (recovery copies), `.agent/saf_log/**` (operational logs), `.agent/operation.lock` (runtime lease), legacy `.agents/backups/**` (recovery copies), and `*.tmp` (atomic-write intermediates). No application binaries, build outputs, caches, or external runtime distributions are maintained here.

## Complete repository tree

- `AGENTS.md/` (repository root)
  - `.agents/`
    - `skills/`
      - `audit-project-docs/`
        - `agents/`
          - `openai.yaml`
        - `SKILL.md`
      - `compress-saf/`
        - `agents/`
          - `openai.yaml`
        - `SKILL.md`
      - `sync-saf/`
        - `agents/`
          - `openai.yaml`
        - `SKILL.md`
  - `.github/`
    - `workflows/`
      - `verify.yml`
  - `scripts/`
    - `local.ps1`
    - `origin.ps1`
    - `publish-saf.ps1`
    - `saf-core.ps1`
  - `templates/`
    - `1_architecture.md`
    - `1_dependency.md`
    - `empty.gitkeep`
  - `tests/`
    - `test-saf.ps1`
  - `.gitattributes`
  - `.gitignore`
  - `AGENTS.md`
  - `LICENSE`
  - `README.md`
  - `README_zh-CN.md`
  - `SAF.json`
  - `SAF.lock.json`
  - `debug.bat`
  - `init.ps1`
  - `local.bat`
  - `origin.bat`

## Responsibilities and dependency direction

| Location | Responsibility |
| --- | --- |
| `AGENTS.md` | Routes task reading, the audit gate, and applicable skills |
| `SAF.json` | Stable release version, handler contract, and normalized source/target/mode/hash inventory |
| `SAF.lock.json` | Locally merged bootstrap, installation, and audit state; source installation/bootstrap may be null |
| `init.ps1` | Source-only trusted bootstrap/recovery; captures caller/explicit Git root, validates one commit, deploys the full handler set and runtime-ignore rules, and records bootstrap provenance without completing payload sync/audit |
| `origin.bat` | Windows wrapper; no arguments default to sync and retain result visibility; explicit actions do not wait |
| `scripts/origin.ps1` | Uses one validated release snapshot to check/update/sync, detects ownership conflicts, protects seeds, handles legacy conversion/retirement, and writes coordinated installation state |
| `local.bat` | Windows local-maintenance wrapper |
| `scripts/local.ps1` | Offline scoped backup, verified archive ZIP export/cleanup, ignore rules, and a no-argument menu defaulting to Backup |
| `scripts/saf-core.ps1` | Shared Git/blob acquisition, hashing/path validation, state merge, operation lease, transaction/recovery, scoped backups, and command logging |
| `debug.bat` | Project-owned seeded menu/dispatcher; optional debug, data-reset, tag-publication, and package-publication slots |
| `.agents/skills/` | Sync workflow, documentation audit, and semantic AI-memory compression; skills are Agent instructions, not a model engine |
| `scripts/publish-saf.ps1` | Source-only release manifest validation/hash preparation and strictly increasing version preparation |
| `templates/` | Explicitly incomplete consumer architecture/dependency documents and empty directory marker; no lock template is imported |
| `tests/test-saf.ps1` | Explicitly invoked disposable-Git-fixture integration checks; no package framework, live network source, or global Git changes required by the suite |
| `.github/workflows/verify.yml` | Default manifest/PowerShell parse checks; optional manually dispatched integration job, on Windows PowerShell 5.1 and Windows/Linux PowerShell 7 |
| `.gitattributes` | Text normalization; BAT checkout uses CRLF |
| `.gitignore` | Local recovery/log/operation-lock and temporary-file exclusions |
| README pair and `LICENSE` | English/Chinese usage and MIT source license |
| `docs-ai/common/` (tree-excluded) | Effective portable shared standards; no mandatory organization namespace, UI library, or package ecosystem |
| `docs-ai/current/` (tree-excluded) | Source project facts/history, separate from consumer templates |
| `docs/` (tree-excluded) | Human documentation area |

There are no application projects, assemblies, shared runtime libraries, databases, microservices, hosted UI, or deployed application units. SAF does not implement model inference, Agent scheduling, or tool registration. Skills execute in the caller's existing Agent session. Project operations are unconfigured examples until a consumer supplies implementations under `scripts/`.

## Runtime and state boundaries

Bootstrap is the independent recovery path, not a permanent application installation. Its five deployed handlers are `origin.bat`, `local.bat`, `scripts/origin.ps1`, `scripts/local.ps1`, and `scripts/saf-core.ps1`. It validates the complete set from one commit before writes, backs up replaced handlers, adds runtime ignore rules, and merges bootstrap metadata while preserving installation/audit evidence. Full payload synchronization is a subsequent origin operation. The actual central source remains `Evigila/AGENTS.md`; a future renamed endpoint is not an implementation dependency.

Daily origin runs the installed local PowerShell code. Remote content is read as a manifest and regular Git blobs from a single resolved commit; it does not execute a separately acquired moving remote controller. Check reports release/compatibility/conflicts without modifying framework files, manifest, or lock, with a local log-only write exception. Sync checks and updates when available using that same snapshot. Update applies a validated plan; only `-update -force` authorizes replacement of conflicting managed content, with recovery copies. Incompatible schema/handlers require init refresh, not historical installer handoff.

Paths are constrained to the repository and reject traversal, unsafe Windows names, linked paths, and invalid source blobs. Text hashes normalize CRLF and an initial UTF-8 BOM. Seed documents and nonempty project debug customizations remain protected, user-added skills are preserved, and Git origin/index/branch/commits are not modified. Legacy conversion preserves genuine old audit/installation evidence; differing old/new project state conflicts rather than silently selecting a winner.

The lock has schema version 1 with independent `bootstrap`, `installation`, and `audit` sections. Writes share repository-local operation coordination and atomic file/transaction helpers. Audit calls `Set-SafState -Root <root> -Section audit -Value <object>`; it cannot replace other sections. Version comparison invalidates an old audit naturally, and neither update nor compression fabricates completion. Operations retain best-effort recovery; arbitrary external concurrent edits, abrupt process/power loss, and permanent external backup retention are not guaranteed by source inspection.

## Local maintenance and memory

Manual snapshots live under `.agent/backup/` and contain scoped handlers/state, `.gitignore`, AI documents, and skills with exact-byte inventories/hashes. This is SAF recovery, not a full source or human-document backup. Logs live under `.agent/saf_log/`; local operation leases use `.agent/operation.lock`. These areas are distinct from `.agents/skills/` discovery.

Archive cleanup resolves Downloads from the current user's Windows User Shell Folders Downloads GUID, supporting redirection; an explicit output destination is also accepted by the script. It exports hidden scoped content through built-in .NET ZIP support, verifies entry/content hashes, and deletes only unchanged exported files, preserving directory markers and changed/new source. Archive-ignore adds child rules with a `.gitkeep` exception and does not change the index. Already tracked content remains tracked; cleanup of tracked content creates local deletion differences for possible later user commits.

Audit and semantic compression are skills only, with no `local.bat -audit` or `-compress` actions and no engine adapter. Compression snapshots recovery data, consolidates active memory, and archives superseded reports while preserving required complete inventories, effective facts, constraints, evidence, unfinished work, changelog immutability, and bug history.

## Verification and current limits

This inventory is based on the maintained SAF 2.0.0 implementation and configuration. Default CI performs manifest validation and PowerShell parsing; optional functional fixtures and interactive/manual acceptance are separate. The subsequent user-authorized Windows PowerShell 5.1 run passed 34 integration checks, including local fixture bootstrap/synchronization, rollback, archive export to a disposable destination, and BAT fallback without PowerShell 7. See the [5.1 verification record](1_changelogs/2026-11-12_115748_powershell-51-verification.md) for results and the long-path limitation. Live network bootstrap, actual Downloads redirection, interactive menus, full debug operations, semantic compression, and runtime checks on other platforms remain unverified. The earlier [implementation record](1_changelogs/2026-11-12_113446_saf-2-upgrade.md) retains its original static-only delivery evidence.
