# Shared execution and documentation rules

## Task boundaries

Follow the effective instruction hierarchy and the user's authorized scope. Reuse existing session instructions and approvals; do not ask for the same authorization again. Read applicable rules and affected implementation before changing files. Keep unrelated refactoring and expansion out of the task.

Preserve access control, domain behavior, session behavior, and public contracts unless modification is authorized. Explain a discovered defect before expanding a narrower task, and continue independent work within scope.

Report conflicts between `common/`, project facts, and human-maintained requirements. An explicit, applicable, already-authorized project exception in `current/` may be followed within its scope. Clarify only unresolved disputed changes; do not rewrite standards to make implementation appear compliant.

Use bounded subagents for separable work when the runtime permits delegation. Keep concurrent write scopes disjoint. The coordinator must inspect, integrate, and verify results. Do not create another user-owned chat solely for internal delegation.

## Document ownership

`docs/` contains human-maintained documentation. AI may read, search, cite, and link it. Without explicit task-scoped authorization, AI must not create, edit, move, rename, delete, or replace its contents. Report stale material rather than silently repairing it.

`docs-ai/` contains AI-maintained standards, facts, decisions, and records. Reusable workflows belong in `.agents/skills/`; skill packaging does not bypass ownership or task authorization. Do not infer AI ownership from writing style.

Do not create documentation outside `docs-ai/` without explicit authorization. Root `AGENTS.md`, `SAF.json`, and `SAF.lock.json` are role-specific exceptions. SAF source maintenance may maintain its authorized README pair, bootstrap, scripts, release metadata, templates, tests, and CI; source-only material is not imported into consumers. `.agent/` contains local operational recovery/log data, not an alternative documentation area. An empty `.gitkeep` is a directory marker, not a requirement that the directory remain empty.

Store prose as `.md` and machine-readable documentation configuration as `.json`; operational logs use JSONL below. Keep toolchain-native formats. Active `AGENTS.md` and `common/` contain only effective policy. Keep dated decisions, approval history, uncertain project-specific guidance, and superseded material in `current/` with clear status.

## Audit gate

Inspect `SAF.lock.json` and its `audit` section at task entry. Perform a full documentation audit when:

- The user requests a full audit or initialization of project documentation.
- The lock/audit state is missing, invalid, or uses an unsupported schema.
- `audit.auditedFrameworkVersion` is missing, null, or differs from `SAF.json.frameworkVersion`.
- `audit.lastCompletedAtUtc` is null, invalid, or later than current UTC time.
- Current UTC time is at least one calendar month after completion.
- Ordinary task work reveals an obviously missing, invalid, or empty required path/document.

Otherwise return `SKIP_AUDIT` and continue the reading routes. This is a workflow decision, not a script command or return from the task. It skips only the full structural/content audit. Do not recursively inspect every required path merely to decide whether a recent audit can be skipped.

Add one calendar month in UTC, preserving time of day and clamping the day to the target month's last valid day. Do not substitute 30 days. New policy takes effect immediately regardless of the timestamp. Handler bootstrap does not complete a project-documentation audit.

## Documentation contract

| Required path | Responsibility |
| --- | --- |
| `AGENTS.md` | Compact instruction router |
| `SAF.json` | Release version, handler compatibility, and payload manifest |
| `SAF.lock.json` | Project-owned bootstrap/installation/audit state |
| `origin.bat`, `local.bat` | Remote management and local maintenance interfaces |
| `debug.bat` | Seeded project-owned operation dispatcher |
| `scripts/` | Handler implementations and project operations |
| `docs/`, `docs/.gitkeep` | Human documentation area and empty marker |
| `docs-ai/common/codedesign.md` | Shared code standards |
| `docs-ai/common/rules.md` | Shared workflow/documentation standards |
| `docs-ai/common/UIUX.md` | Shared UI integration standards |
| `.agents/skills/` | Project-owned skill packages |
| `docs-ai/current/1_architecture.md` | Complete repository tree and architecture |
| `docs-ai/current/1_dependency.md` | Current dependency inventory |
| `docs-ai/current/1_changelogs/` | Append-only changes |
| `docs-ai/current/1_bugreports/` | Diagnosis and regression evidence |
| `docs-ai/current/1_archived/` | Superseded or abandoned material |

Keep exact names/capitalization and the `1_` prefixes. Other active AI project documents belong directly under `current/`. Required directories may use empty `.gitkeep` markers. Archive ignore does not require tracking archive content; retain/recreate the local directory.

### Architecture file

`1_architecture.md` contains a complete hierarchical tree from the repository root to every maintained file in scope. Exclude `docs/`, `docs-ai/`, Git internals, `.agent/backup/`, `.agent/saf_log/`, temporary/generated material, build outputs, and caches; document concrete patterns. Ignore rules alone do not justify excluding maintained source/configuration/deployment files or checked-in assets. Include intentionally untracked maintained files.

Explain root files, modules, applications/libraries, dependency direction, and verified runtime/resource boundaries separately. Multiple projects do not establish microservices. Update the tree for file moves/additions/removals and descriptions for changed responsibilities/boundaries. A template or representative-path summary is not a completed inventory.

### Dependency file

`1_dependency.md` records every dependency actually used: direct and resolved transitive packages, SDKs/runtimes, local project references, services, assets, and build/test/development tools. Distinguish production, build, test, development, and optional use.

Record identity, kind, declared constraint versus resolved version, direct/transitive relationship, consumers, purpose, and declaration/resolution evidence. Record verified sources/licenses where applicable and mark unknowns. Describe service contracts rather than invent versions. Never store credentials or secret connection data.

Use manifests, central configuration, locks, references, and available resolution reports. Update actual dependencies when they change; proposals are not active dependencies and inventory entries do not authorize adoption.

### History and archives

Name change records `YYYY-MM-DD_HHmmss_<lowercase-slug>.md` using the documented project zone, else the user's known zone, else UTC. Record the zone and offset. Imported records with unknown time use `000000`, preserving original identifiers/provenance.

`1_changelogs/` is append-only: correct a record through a new linked entry. Bug reports distinguish symptoms, root cause, evidence, fix/mitigation, limitations, and regression verification; add dated findings or follow-ups rather than erase earlier diagnoses.

Archive superseded/abandoned designs in `1_archived/`, with status, reason, scope, and replacement when available. Archived material does not govern new work. Memory compression does not relocate changelogs or rewrite bug evidence. Explicit archive-export cleanup follows the separate local contract below.

### SAF state

`SAF.lock.json` uses schema version `1` and separate `bootstrap`, `installation`, and `audit` sections. Bootstrap describes deployed handlers; installation describes synchronized payload, exact source repository/ref/commit, manifest digest, normalized managed-file baselines, and synchronization time. They may differ after handler recovery. Either may be null before its operation succeeds; the source repository may have both null.

Audit contains `auditedFrameworkVersion`, `lastMissingMaterialAskedAtUtc`, and `lastCompletedAtUtc`. UTC timestamps use ISO 8601 ending in `Z`. Initialize audit values to null for a new consumer; preserve genuine prior evidence during migration. State is neither instructions nor authorization.

All state writers use `scripts/saf-core.ps1`'s common read/merge/atomic-write implementation and operation lock. Audit writers dot-source that helper and call `Set-SafState -Root <root> -Section audit -Value <audit-object>`; do not rewrite the entire JSON or discard bootstrap/installation. Preserve the latest applicable question time and write actual completion only after a successful full audit. If the helper is missing/incompatible, report the issue rather than bypass coordination.

Bootstrap/synchronization never mark audit complete. Version changes make audit due by comparison without fabricating completion. Track the lock with installed framework files; logs/backups remain outside it and ignored.

## Full documentation audit

Use [audit-project-docs](../../.agents/skills/audit-project-docs/SKILL.md). Verify every required path, substantive content, complete architecture tree, and dependency inventory against evidence. The source repository may have null bootstrap/installation; do not invent a consumer installation.

Resolve gaps from available sources and authorization first; consolidate genuinely unavailable facts into one question. Continue independent work. Preserve human content; only missing structural directories/empty markers may be initialized without a content-edit request. Leave completion unchanged while essential facts remain unverifiable. Partial/ordinary inspections do not refresh completion, and documentation auditing does not prove functional tests passed.

## Framework synchronization

Use existing Git, Windows CMD, Windows PowerShell 5.1, or already available PowerShell 7. Do not install an application, global CLI, package, service, or runtime, modify PATH/global Git configuration, or permanently change execution policy. Windows BAT interfaces do not imply cross-platform entry points.

`SAF.json` defines a stable `major.minor.patch` release, handler contract, and exact source/target/mode/normalized SHA-256 inventory. Bump the release when installed payload/manifest changes. It does not hash itself; installation state records its digest and source commit. Source-only documentation commits are not automatically framework payload updates.

Source-only `init.ps1` provides remote bootstrap/recovery from a trusted source. Capture the caller's filesystem directory and require the target Git root; do not derive an `irm | iex` target from script-file variables. Resolve one commit, validate all handlers before writes, back up replacements, preserve project facts and existing audit/installation sections, and deploy both BAT handlers and required PowerShell helpers. Bootstrap does not silently synchronize full payload or exit the caller's shell. Payload hashes establish consistency, not independent authentication of the already-executed bootstrap.

Daily `origin.bat` uses its deployed local implementation to read one validated remote snapshot. Do not execute a second independently moving remote controller or fall back to unverified code. Incompatible handler/schema results require bootstrap refresh before payload writes. Recover through trusted init rather than delete state. SAF 2 does not promise historical pre-SAF installer handoff/rollback support.

| Command | Contract |
| --- | --- |
| `origin.bat -check` | Report validated availability, compatibility, and conflicts. No framework/manifest/lock changes; only `.agent/saf_log/` command logging may write locally. |
| `origin.bat -update` | Apply the selected release or report current/no-op. Stop on managed conflicts. |
| `origin.bat -sync` | Check, then update when available, using one resolved commit/change plan. |
| `origin.bat -update -force` | Back up/replace conflicting managed files; may allow requested downgrade. |
| `origin.bat` | Select sync automatically, then wait after completion to show results. |

Explicit action parameters have no initial confirmation or final wait. Reject conflicting actions and isolated `-force`; Force applies only to Update. Exit codes: `0` successful/current, `1` error, `2` update available from Check, `3` conflict, `4` bootstrap refresh required. Version-only requests do not authorize update/Force. Do not check the network during unrelated tasks.

Read regular Git blobs from one resolved commit and validate the entire payload before changes. Reject traversal, unsafe linked paths, duplicates/reserved targets, invalid modes, and hash errors. Normalize CRLF to LF and remove an initial UTF-8 BOM for text hashes. Manage only permitted manifest paths and prior owned paths. Never alter the target Git origin, index, branch, or commits.

Detect committed/uncommitted customization against imported baselines. Force never bypasses path/payload checks or project ownership. Seed missing project facts/directories/debug entry points without overwriting current documents or nonempty project customizations. Preserve user-created skills and unrelated files. Update state after successful synchronization; retain recovery evidence and report partial failures accurately.

For legacy migration, preserve old baselines and real audit evidence before conversion. Move nonempty `debug-handler.bat` to `debug.bat` only when the target is absent; differing existing files conflict. Retire only verified old owned artifacts after new state/layout succeeds, retaining recovery copies. Historical records keep original terms.

## Local maintenance

`local.bat` performs offline mechanical operations. Audit/compression are Agent skills, not local commands; do not add model dispatchers, engine adapters, or task-request files. `.agents/skills/` is discovery; `.agent/` contains local operational data.

No-argument local invocation shows a menu: Backup first/default, archive export/cleanup, archive ignore, Exit. Empty Enter chooses Backup, invalid input repeats, EOF cancels, and a final wait shows results. Explicit actions run without waits and reject incompatible flags.

### Backup

`local.bat -backup` creates `.agent/backup/<UTC-time>-<unique-id>/` with exact scoped bytes, inventory, and hashes of SAF handlers/state, AI project documents, and skills. State its SAF recovery scope; it is not a full source backup. Exclude previous backups, logs, Git internals, temporary/build caches, and unrelated source. Automatic backups use the same conventions and record the triggering action. An incomplete snapshot is not a successful recovery point.

### Archive export and cleanup

`local.bat -clean-arquived` exports only `docs-ai/current/1_archived/` to a unique ZIP in the user's real Windows Downloads folder obtained from the Windows User Shell Folders Downloads GUID. Do not assume a literal profile directory. Reject linked/traversing paths or output inside source.

Include hidden scoped files. Reopen the ZIP and verify relative paths, entry counts, and content hashes before deleting anything. Recheck source files and delete only unchanged exported content; preserve/report new or modified files. Retain/recreate the archive directory and empty marker. Export/verification failure preserves source; partial cleanup reports remaining content and recovery ZIP. A local ZIP is not a permanent external-retention guarantee.

Cleaning tracked archives creates local Git deletions; later user commits may remove them from a remote branch. SAF does not stage, commit, or push. This differs from ignore-only behavior.

### Archive ignore

`local.bat -no-arquived` idempotently adds root-scoped archive-child ignore rules while preserving `1_archived/.gitkeep` and existing `.gitignore` content. It does not modify index, commit, push, or remove remote files. Already tracked archives remain tracked; report that limitation. Never automatically run `git rm --cached`.

### Command logs

Append logs under `.agent/saf_log/<UTC-date>.jsonl`, excluded from synchronization and version control. Record operation ID, UTC start/completion times, action, result/exit code, affected relative paths, relevant versions/commits, and backup/export references. Exclude secret arguments, credential-bearing URLs, tokens, and complete file contents. Logs are operational evidence, not project change history. Show log failures without obscuring the real operation result.

## Memory compression

Use [compress-saf](../../.agents/skills/compress-saf/SKILL.md) for authorized semantic consolidation of `docs-ai/current/`. Make a recovery snapshot first. Remove repetition and archive superseded active reports only after retaining effective facts, constraints, decisions, unresolved issues, compatibility, provenance, verification status, and unfinished work in accessible current material.

Preserve complete required inventories. Do not rewrite/delete/relocate append-only changelogs or bug evidence. Do not modify human `docs/`, shared policies, source, dependency declarations, installation state, or audit completion as a side effect. Archives identify status/reason/replacement. Update active links and report consolidation/archiving. Semantic compression is not archive ZIP cleanup and does not complete an audit.

## External dependencies

Do not add, replace, or upgrade external dependencies without explicit task authorization, including packages, SDKs, services, fonts/icons, and build/runtime/deployment components. An unrelated feature is not blanket approval. Before seeking missing approval, prepare the need, alternatives, compatibility, impact, and affected declarations/inventory; do not install dependencies to prepare that explanation.

Apply approved changes through existing dependency management, verify affected behavior/builds as authorized, and update `1_dependency.md`. Inventory entries do not authorize adoption.

## Project scripts and entry points

Implement operations under root `scripts/`. AI-created consumer root scripts are exactly `origin.bat`, `local.bat`, and `debug.bat`. SAF source additionally owns source-only `init.ps1`; this exception does not allow arbitrary consumer root scripts.

Project debugging, data resets, and publication use project-owned `debug.bat`. The seed offers Debug, Clear database, Publish tag, Publish package, and Exit; projects may adapt authorized operations without adopting a mandatory ecosystem. Dispatch under `scripts/` and report missing implementations. Preserve nonempty project customizations, including under Force.

The debug seed shows a menu, defaults to Debug on empty Enter, repeats invalid input, cancels EOF, and waits before exit while retaining the operation code. Explicit noninteractive selection may skip waits. Isolate child BAT execution so its `exit` cannot close the parent; restore working directory and use `exit /b`. Origin/local retain their own contracts above.

## Implementation and verification

Use [codedesign.md](codedesign.md) and [UIUX.md](UIUX.md) as applicable. Use inspection, static analysis, builds, automated tests, and focused regression checks as authorized and proportional to risk. Do not use Computer Use for project testing. Provide recommended manual acceptance steps for functional behavior needing user verification.

Distinguish passed, failed, and unperformed checks with reasons. Structural inspection does not prove runtime behavior. Follow task-specific testing limits, including static-only verification when requested.

## Delivery and records

Synchronize durable facts with actual changes. Record material implementation/decisions in `1_changelogs/`, investigations in `1_bugreports/`, and superseded designs in `1_archived/`. Do not create changelogs for read-only analysis with no lasting change unless requested or needed to preserve an important finding.

Distinguish implemented facts, verified results, assumptions, proposals, and outstanding work. Keep records concise/linked. At completion report affected modules/files, actual verification, unresolved work/reasons, limitations, and recommended manual checks.

When functionality is complete, ask about a Git commit unless already authorized/declined. Do not commit without authorization; match recent commit-subject style.
