# SAF 2.0.0

[English](https://github.com/Evigila/AGENTS.md/blob/main/README.md) | [简体中文](https://github.com/Evigila/AGENTS.md/blob/main/README_zh-CN.md)

SAF distributes lightweight instructions, Agent skills, project memory, and repository-local Windows handlers into existing Git repositories. It installs no application, global CLI, service, package manager, or runtime, and imposes no product namespace or UI library.

## Initialize and recover

Requirements: an existing Git repository, Git on PATH, and Windows PowerShell 5.1 or already installed PowerShell 7. The BAT interfaces require Windows. Work from the target Git root.

After this release's init script is published to the configured repository's main:

```powershell
irm https://raw.githubusercontent.com/Evigila/AGENTS.md/main/init.ps1 | iex
.\origin.bat -sync
```

The repository remains Evigila/AGENTS.md. A future Evigila/SAF endpoint is not assumed to exist, and the remote command requires publication. Before publication, use a trusted source checkout:

```powershell
& C:\path\to\source\init.ps1 -ProjectRoot C:\path\to\target
```

Init captures the caller's directory, resolves one commit, and deploys both BAT handlers plus scripts/origin.ps1, scripts/local.ps1, and scripts/saf-core.ps1. It backs up replaced handlers, adds local runtime ignore rules to existing .gitignore, and preserves project facts and installation/audit evidence. Run origin afterward for full payload synchronization. Rerun trusted init for broken/incompatible handlers; do not delete the lock.

Init accepts -ProjectRoot, -Repository, and -Ref. For explicit downloaded-script parameters:

```powershell
$initUrl = 'https://raw.githubusercontent.com/Evigila/AGENTS.md/main/init.ps1'
& ([scriptblock]::Create((irm $initUrl))) -Repository 'https://github.com/Evigila/AGENTS.md.git' -Ref main
```

Review/trust bootstrap code before execution. A published commit-pinned URL improves reproducibility; payload hashes do not independently authenticate already-executed bootstrap code.

## Files and commands

| Path | Responsibility |
| --- | --- |
| AGENTS.md and docs-ai/common/ | Reading routes and effective standards |
| .agents/skills/ | sync-saf, audit-project-docs, compress-saf; user skills coexist |
| SAF.json | Release version, handler compatibility, payload hashes |
| SAF.lock.json | Separate bootstrap, installation, and audit state |
| origin.bat and scripts/origin.ps1 | Remote checking and synchronization |
| local.bat and scripts/local.ps1 | Offline mechanical maintenance |
| scripts/saf-core.ps1 | Shared paths, hashes, state merge, and operation locks |
| debug.bat | Seeded project-owned operation dispatcher |
| docs-ai/current/ | Project facts, changes, bug evidence, and archives |
| docs/ | Human documentation; AI edits require explicit authorization |
| .agent/backup/ and .agent/saf_log/ | Ignored local recovery snapshots and logs |

Track framework files and state in Git. Source README, init, publisher, tests, CI, and templates directory are not consumer payload. New fact templates remain incomplete until project audit.

| Command | Result |
| --- | --- |
| origin.bat -check | Check release, compatibility, and local conflicts |
| origin.bat -update | Apply selected release or report current |
| origin.bat -sync | Check, then update when available, from one commit |
| origin.bat -update -force | Back up and replace conflicting managed files |
| origin.bat -Repository "Git URL" -Ref "branch/tag/commit" -sync | Select compatible source/ref |

No arguments/double-click selects sync and waits after completion. Explicit actions have no confirmation or final wait. Reject conflicting actions and isolated Force; Force modifies Update only. Seeds, project facts/customizations, user skills, path/payload checks, and target Git origin/index/branch/commits remain protected.

Check changes no framework files, manifest, or lock; its only local write exception is .agent/saf_log logging. Daily origin runs deployed local code and reads verified release data, without executing another moving remote controller. Exit codes: 0 success/current, 1 error, 2 update available from Check, 3 conflict, 4 bootstrap refresh required.

## Local maintenance and skills

No-argument local shows a menu, default Backup. Enter selects Backup; invalid input repeats, EOF cancels, and results remain visible until final input. Explicit actions have no waits.

- local.bat -backup: scoped SAF recovery under .agent/backup/<UTC-time>-<unique-id>/ with exact framework/state/AI-document/skill bytes, inventory and hashes; excludes old backups, logs, Git internals, caches, and unrelated source. This is not a full repository backup.
- local.bat -clean-arquived: ZIP docs-ai/current/1_archived into the user's real Windows Downloads folder, verify all entries/content including hidden files, then delete only unchanged exported files. Preserve the directory/marker; report partial cleanup. Failed export/verification preserves source.
- local.bat -no-arquived: append archive-child ignore rules preserving .gitkeep and existing content, without index changes, commit, push, or remote deletion.

The requested arquived spelling is retained. Already tracked archives remain tracked. Cleaning tracked archives creates Git deletion differences; later user commits may remove them remotely. Downloads is read from the Windows User Shell Folders Downloads GUID, including redirection.

Append logs under .agent/saf_log/<UTC-date>.jsonl with action/results/recovery references, without secrets or whole-file contents. Logs do not replace project history.

Use $sync-saf, $audit-project-docs, or $compress-saf in an Agent session; engines without discovery can read SKILL.md. Audit/compression are skills only: no local -audit/-compress commands or model adapter. Audit merges only its section through the shared state helper. Compression snapshots recovery data, preserves complete inventories/effective constraints/unfinished work, and archives superseded active reports without rewriting changelogs or bug evidence. Neither bootstrap/update nor compression completes an audit.

The debug seed provides optional Debug, Clear database, Publish tag, and Publish package slots. Configure implementations under scripts/; no ecosystem is mandatory. Nonempty customization survives update/Force. Explicit selection such as debug.bat 1 skips waits.

## Migration and verification

Preserve legacy installation/audit evidence during lock conversion; conflicting existing state is not guessed away. Preserve debug customization or report conflicts. SAF 2 does not promise pre-SAF installer rollback; recover through trusted init.

Static checks do not prove functional behavior. Recommended manual checks: bootstrap/recovery; check/update/sync/conflict/Force; audit preservation; offline backup; redirected Downloads/export failures; tracked-archive ignore behavior; audit/compression content and state preservation. Do not use Computer Use for project testing.

## License

[MIT License](https://github.com/Evigila/AGENTS.md/blob/main/LICENSE). Developed with AI Agent assistance.

