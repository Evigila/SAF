# SAF upgrade proposal

**Historical proposal, implemented with documented adjustments:** SAF 2.0.0 supersedes this proposal as active guidance. See the [implementation record](1_changelogs/2026-11-12_113446_saf-2-upgrade.md) and current inventories for actual behavior, verification, and remaining manual acceptance. The proposal below is retained unchanged as decision history; its recommendations are not independent current instructions.

## Status and evidence

Status: Design proposal, not implemented. Prepared on 2026-11-12, America/Sao_Paulo (UTC-03:00), from the working repository based on `c89cf42b28b6ea540c4b109f614e016971d7eb32`, the user's upgrade requirements, and the [shared conversation](https://chatgpt.com/share/6af5c2be-9bd8-83e9-b59b-9df7224ea892). The conversation was read through the browser after direct web retrieval failed. Its statements about the existing implementation were checked against local source rather than treated as implementation evidence.

The user subsequently removed audit and semantic compression from `local.bat`; both are to be Agent skills. The currently effective release remains `1.2.1`. Existing rules and filenames remain effective until an implementation changes them together. The recent audit state passed the audit gate, so this analysis did not repeat or refresh the full audit.

## Goals and confirmed requirements

- Remain useful to general Git repositories, without installing a SAF application, global CLI, package manager, or service, or modifying PATH. Git remains an accepted prerequisite. Windows CMD and Windows PowerShell 5.1 are the baseline; an existing PowerShell 7 can also be supported. The BAT entry points are Windows interfaces, not a claim of universal OS support.
- Provide a remote PowerShell `init.ps1` for `irm <URL> | iex` initialization, followed by repository-local handlers.
- Split remote framework management into `origin.bat` and local mechanical maintenance into `local.bat`.
- Keep `AGENTS.md`; rename the release manifest to `SAF.json`, and combine installation and documentation-audit state in `SAF.lock.json` without merging their meanings.
- Rename `sync-agents-framework` to `sync-saf`, and `debug-handler.bat` to `debug.bat`.
- Add command logging named `saf_log`, manual backups at `.agent/backup/`, archive export/cleanup, and an archive-ignore operation.
- Provide audit and memory compression through skills, with no BAT-to-model engine or task-request adapter required.

## Proposed responsibility split

| Artifact | Responsibility |
| --- | --- |
| `init.ps1` | Remote bootstrap and independent recovery of handlers; source-only by default |
| `origin.bat` | Thin Windows entry point for check/update/sync/force |
| `local.bat` | Thin Windows entry point for backup/export cleanup/archive-ignore |
| `scripts/origin.ps1` | Local synchronization implementation that acquires and validates remote release data |
| `scripts/local.ps1` | Local file maintenance; does not fetch a remote controller |
| `debug.bat` | Project-owned operation dispatcher, seeded rather than centrally overwritten |
| `SAF.json` | Release version, supported/required handler contract, and exact payload inventory |
| `SAF.lock.json` | Project-owned bootstrap provenance, installation baselines, and audit state |
| `.agents/skills/sync-saf/` | Explicit framework check/update workflow |
| `.agents/skills/audit-project-docs/` | Existing documentation audit workflow, adapted to the new state layout |
| `.agents/skills/compress-saf/` | Proposed name for semantic review and consolidation of active AI project memory |
| `.agent/backup/` | Local recovery snapshots, excluded from synchronization and version control |
| `.agent/saf_log/` | Proposed location for append-only command logs, excluded from version control |

`.agents/skills/` remains the skill discovery location. `.agent/` is the user-requested local maintenance area. They are distinct; neither handler may treat the entire `.agents/` tree as disposable cache. Shared logging, hashing, backup, and state-writing helpers may be factored under `scripts/` if implementation demonstrates duplication; their exact packaging is not fixed by this proposal.

The shared conversation correctly separates one-time bootstrap from daily commands. Its suggestion that daily calls no longer download a handler does not describe the current BAT: `fetch-agents.bat:56-64` clones and executes the central controller on every call. This proposal recommends changing that behavior: the deployed local PowerShell implementation reads one remote release snapshot, validates data, and performs the operation. It does not automatically execute a second controller from an independently moving central `main` branch.

## Bootstrap and recovery contract

The eventual convenience command is `irm <published-init-url> | iex`, executed from PowerShell at the target Git root. The future `Evigila/SAF` URL is not presented as a working endpoint before that repository/path is published.

`init.ps1` should:

1. Capture the caller's filesystem working directory and verify it is the target Git root. Do not infer a target from `$PSScriptRoot` or `$PSCommandPath` when evaluating a downloaded string.
2. Check existing Git and PowerShell availability without installing software, changing execution policy permanently, or writing global configuration.
3. Resolve one source commit and retrieve the manifest plus the complete handler set from it. Download and validate the full set in temporary storage before project writes.
4. Deploy both BAT files **and any local PowerShell files they need**. Only downloading two BAT files that call absent PS1 files would leave initialization unusable. The handler set and its allowed paths must be explicit.
5. By default, replace the known SAF handler paths requested for bootstrap recovery. Back up their previous bytes first; do not replace arbitrary project scripts or facts. Preserve the previous working handler set if replacement fails.
6. Preserve existing installation baselines and audit evidence while recording the new bootstrap provenance. On first bootstrap, installation and audit may remain null because payload synchronization and project audit have not yet happened.
7. Print the next command, `./origin.bat -sync`. Proposed default: bootstrap deploys usable handlers but does not silently apply the full framework payload. This two-step default follows the user's initialization sequence; full injection occurs through the subsequent origin command.

Because `iex` evaluates a string in the current scope, initialize within a bounded scope and avoid `exit` that could close the user's PowerShell session. This behavior is documented by [Invoke-Expression](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-expression?view=powershell-5.1). Subsequent handler execution should use normal script invocation and bound parameters, rather than construct another expression from user input.

Compatible handler changes can be synchronized normally. Updating an executing BAT still requires a deliberately preloaded finishing block or a staged child process: a new bootstrap does not itself solve the in-flight replacement problem. The existing BAT already has a relevant finishing-block pattern. Incompatible schema/handler changes should stop with a specific message to rerun `init.ps1` before any payload writes. Manual deletion of the two BAT files is unnecessary because initialization replaces them by default. Recovery must refresh required PS1 files too; replacing only BAT files cannot repair an incompatible PS1 implementation.

The bootstrap is an independent recovery route. This permits removal of historical installer protocol 1/2 handoff and multi-generation rollback/re-upgrade compatibility. Retain one declared handler compatibility contract and same-commit data validation. Do not claim support for pre-SAF payload rollback unless that support is explicitly retained and tested.

`irm | iex` trusts the downloaded bootstrap source before its code runs. Payload hashes verify later content consistency; they do not independently authenticate the already-executed bootstrap. Offer a fixed-release/commit URL as a reproducibility option without installing another trust service.

## Origin command contract

The user's definition of sync is retained: **check, then update when available**. It is not renamed to mean restoration of a pinned release.

| Invocation | Proposed behavior |
| --- | --- |
| `origin.bat -check` | Resolve the configured remote release, validate it, and report version availability, compatibility, and local conflicts. Do not change framework files, `SAF.json`, or `SAF.lock.json`. |
| `origin.bat -update` | Resolve and apply the selected release through one validated change plan. Report current/no-op when no update is needed. Conflicts stop the operation. |
| `origin.bat -sync` | Build the check result and update plan from the same resolved commit; apply only when an update is available and compatible. Never resolve a moving branch again between its check and update phases. |
| `origin.bat` / double-click | Select `-sync` by default, as requested. |
| `origin.bat -update -force` | Back up and replace conflicting managed framework files. Preserve seed/project files and enforce all path/payload checks. |

Reject mutually exclusive action flags and an isolated `-force`. A configuration/source change should be explicit, and origin must not rewrite the target repository's Git remote, index, branch, or commits.

Recommended interaction revision: explicit action flags run without a second prompt or final pause; a no-argument double-click selects sync automatically and keeps the final result visible. This replaces the old mandatory numbered-selection contract and needs a deliberate shared-rule/test update. `local.bat` can show a safe operation menu when no action is supplied. Destructive archive cleanup should still explain its export location and scope before executing according to its explicit action contract.

Preserve useful existing origin exit meanings: 0 successful/current, 1 error, 2 update available for check, 3 local conflict. Reserve 4 for a required bootstrap refresh. These are recommendations for the new contract, not current executable behavior.

## State-file consolidation

Combining root files is appropriate if the internal boundaries remain explicit. A representative, non-final schema is:

```json
{
  "schemaVersion": 1,
  "bootstrap": {
    "handlerProtocolVersion": 1,
    "repository": "<source>",
    "ref": "<ref>",
    "commit": "<exact commit>",
    "managedFiles": {}
  },
  "installation": {
    "frameworkVersion": "<version>",
    "repository": "<source>",
    "ref": "<ref>",
    "commit": "<exact commit>",
    "manifestSha256": "<digest>",
    "managedFiles": {},
    "synchronizedAtUtc": "<UTC timestamp>"
  },
  "audit": {
    "auditedFrameworkVersion": null,
    "lastMissingMaterialAskedAtUtc": null,
    "lastCompletedAtUtc": null
  }
}
```

Bootstrap metadata describes handlers installed through init; installation describes the framework payload actually synchronized. Their snapshots may temporarily differ after handler-only repair. Central source can have `bootstrap: null` and `installation: null` while retaining its own audit state. New consumer audit fields remain null until a real audit succeeds. Runtime locks are generated/merged locally, never copied from the central source's own completed audit state.

Origin updates only its owned installation/bootstrap fields. The audit skill updates only audit fields. A new framework version invalidates audit by comparison with `audit.auditedFrameworkVersion`; it does not refresh completion time. All writers must use a common read/merge/atomic-write contract with coordination or optimistic revision checks, and reread before committing changes. Atomic replacement alone does not prevent one writer from losing another writer's state. Command logs and backup indexes stay outside the lock.

`SAF.json` remains release-owned and contains no consumer audit completion. Keep normalized file hashes, ownership modes, and the manifest digest in installation state. Track the project lock in Git; ignore local backups/logs instead.

## Local maintenance contract

Audit and memory compression are skills only; there are no `local.bat -audit` or `local.bat -compress` commands in this proposal after the user's clarification.

### Backup

`local.bat -backup` creates `.agent/backup/<UTC-time>-<unique-id>/` with an explicit file inventory, hashes, and exact contents of SAF handlers/state, AI project documents, and applicable skill files. Recommended scope is SAF recovery rather than a full source-repository backup; the command must display that scope. Exclude previous backups, logs, temporary caches, Git internals, and unrelated source/build trees. A failed snapshot is not reported as a completed recovery point. Automatic pre-change backups should use the same storage conventions while identifying their triggering operation.

### Archive export and cleanup

Retain the requested command `local.bat -clean-arquived`; optionally accept `-clean-archived` as a correctly spelled alias. Its only source is `docs-ai/current/1_archived/`.

1. Resolve and validate that exact source directory; refuse linked destinations, traversal, and an output inside the source.
2. Resolve the current user's real Downloads folder through the Windows Known Folder mechanism rather than assume a literal profile subdirectory. See [SHGetKnownFolderPath](https://learn.microsoft.com/en-gb/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath).
3. Create a uniquely named ZIP and inventory; include hidden files. Reopen it and verify relative paths, entry counts, and file content hashes before cleanup.
4. Recheck that each source file still matches the exported snapshot. Delete only verified unchanged exported files; retain and report new or modified files. Never force an empty directory by deleting material that was not verified in the export.
5. Keep the archive directory and, under the existing directory contract, its empty `.gitkeep` marker. Report partial deletion or export failure accurately, including the recovery ZIP path.

Using `Compress-Archive` blindly is insufficient for this operation: its documented behavior skips hidden content and notes file-size limitations. Use an appropriate built-in .NET archive path with explicit supported limits and content verification. See [Compress-Archive](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.archive/compress-archive?view=powershell-5.1). No external compressor is required by this design.

Cleaning a tracked archive creates local Git deletion differences. The command does not commit or push them, but a later user commit may remove those files from the remote branch. That behavior differs from the ignore-only command below.

### Archive ignore

`local.bat -no-arquived` (optional alias `-no-archived`) idempotently adds a root-scoped rule such as `/docs-ai/current/1_archived/` to the existing `.gitignore`, preserving other content. It performs no index modification, commit, push, or remote deletion.

Already tracked files remain tracked: this is the [documented Git behavior](https://git-scm.com/docs/gitignore). Report them and explain the optional user-run `git rm -r --cached -- docs-ai/current/1_archived/` workflow. That command changes the index, and a subsequent commit/push removes files from the current remote branch while retaining local copies; it does not erase repository history. Do not run it automatically as part of ignore configuration. The ignored directory marker may remain on disk; initialization/audit should recreate missing runtime directories without requiring tracked archive content.

## Skills and memory policy

- `sync-saf`: rename the current synchronization package, its front matter/UI metadata, links, and command/state references together.
- `audit-project-docs`: retain the existing documentation audit scope and evidence requirements; adapt reads/writes to `SAF.json` and the audit section of `SAF.lock.json`. It is not silently expanded into a security or code audit.
- `compress-saf`: proposed new package name, explicitly scoped to semantic project memory under `docs-ai/current/`. It reviews actual evidence, archives superseded active reports, consolidates remaining active material, and records the replacement/provenance links.

Compression must preserve current facts, user constraints, unresolved problems, dependency/architecture completeness, compatibility boundaries, verification status, and unfinished work. It must not infer AI ownership from writing style. Human `docs/`, required complete inventories, and append-only history retain their ownership/retention rules. Existing changelogs and bug evidence are excluded from automatic rewriting, deletion, or relocation; ordinary routing already avoids reading irrelevant history. Overriding those preservation rules would require a separately defined change to history policy. A compression task should create a recovery snapshot and a concise record of archived/replaced content.

For the stated generic audience, move mandatory Arkheide namespace and Flourish UI policies out of the mandatory shared defaults. Reuse the consumer's established naming, technology, design system, and public contracts instead. Merely renaming the repository to SAF would leave the confirmed portability gap in place. A fixed NuGet publication menu is likewise an ecosystem default; recommend a project-configured `debug.bat` operation menu, preserving all nonempty project customizations.

## Command logging

Recommended `saf_log` format: `.agent/saf_log/<UTC-date>.jsonl`, append-only, with operation ID, start/end times, action, result/exit code, affected relative paths, before/after version or commit when applicable, and backup/export references. Do not include credentials, unsanitized credential-bearing URLs, complete file contents, or secrets from arbitrary command arguments. Skills can emit their own completion records using the same schema when they actually execute; the shell does not claim to observe unrelated manual Agent work.

There is a contract choice: logging every `-check` invocation writes a local file, so the old promise of zero writes anywhere in the project cannot simultaneously hold. Recommended SAF behavior is **no framework/manifest/lock writes during check, with an explicit local log-only exception**. A stricter read-only mode can disable file logging if later required. This is a proposal that must be reflected in documentation and tests, not silently presented as the old zero-write behavior. Logging failure should be visible and must not disguise a completed file operation as having never happened.

## Migration and affected scope

Recommended release boundary: a new SAF major version, because entry points, filenames, lock schema, recovery contract, and policy portability all change.

1. Preserve old metadata and hashes before conversion. Translate `AGENTS.lock.json` to installation state and `AGENTS.ensure.json` to audit state; keep source/ref/commit/digest/baselines and genuine audit timestamps.
2. Generate `SAF.json` from the new release, not by merely renaming the old installed manifest. Never overwrite a conflicting already-existing SAF state by guessing from timestamps.
3. Refresh the complete handler set through init. Use a single change plan/recovery point for a one-time migration; do not make daily synchronization interpret every historical installer protocol.
4. Rename the sync skill only when it is centrally owned and safe to retire. Preserve project-created packages and modified managed content unless replacement is explicitly forced and backed up.
5. Move nonempty `debug-handler.bat` to `debug.bat` only when the target is absent and the move preserves its bytes; if both exist and differ, report a project-file conflict. Framework Force does not authorize replacing project-owned debug operations.
6. Verify the new layout and state before retiring old framework paths. Remove only verified old owned artifacts, not arbitrary similarly named files. Retain migration recovery copies. Existing append-only history keeps its original filenames and terminology.

The implementation must update the router, root-script allowlist, required-path contract, audit gate, state schemas, synchronization skill, audit skill, new compression skill, source/target path validators, manifests/publisher, consumer templates, README pair, architecture/dependency facts, tests, and CI commands together. The user explicitly authorizes the new root `init.ps1` exception and BAT names for this upgrade; other operation scripts remain under `scripts/`. Future repository naming is configuration, not permission to rename a consumer's Git origin.

## Recommended manual acceptance checks

1. Fresh `irm | iex` bootstrap from Windows PowerShell 5.1 and existing PowerShell 7 at a Git root, including spaces/non-ASCII paths; reject a non-root working directory before target writes.
2. Verify that both handlers can run immediately after init, before payload synchronization; initialize again over customized/broken handlers and confirm backups plus preservation of project facts/state.
3. Interrupt download or replacement; confirm that the previous complete handler set remains recoverable and partial initialization is reported.
4. Exercise check/update/sync/current/conflict/Force; verify sync uses one resolved commit and only Force replaces managed customizations, with exact backups.
5. Present an incompatible handler/schema release; confirm a bootstrap-refresh result before payload writes, then rerun init and retry.
6. Run local backup/ignore/export operations while offline. Verify backups exclude themselves, include hidden scoped files, and accurately state their restoration scope.
7. Redirect Downloads, lock an archive source, change a file during export, and inject archive/write failures. Verify no unexported/changed content is deleted and partial cleanup is reported.
8. Add ignore rules twice, with both tracked and untracked archives; confirm idempotence and no index/remote changes. Separately review the deletion differences caused by export cleanup.
9. Update installation and audit in interleaved/concurrent operations; verify state sections are not lost and synchronization never marks an audit complete.
10. Run the audit and compression skills in an existing Agent session; verify preservation of required inventories, user constraints, unresolved work, human documentation, and append-only history.
11. Verify command log success/failure/cancellation records and credential redaction, including the documented check log-only write exception.
12. Migrate an old consumer with committed managed customizations, a custom debug menu, and both old/new state present; confirm conflicts preserve all recovery evidence.

No new commands or initialization endpoint were implemented or executed during this analysis. No software was installed, no archives were cleaned, no Git index or remote was modified, and no Computer Use testing was performed. Browser use was limited to reading the supplied conversation. No release version or audit timestamp was changed by this proposal.
