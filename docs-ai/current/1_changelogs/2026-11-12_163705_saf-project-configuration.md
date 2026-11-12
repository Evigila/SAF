# SAF project configuration and unified runtime storage

- Recorded: 2026-11-12 16:37:05, America/Sao_Paulo (UTC-03:00).
- Status: implemented and locally verified; prepared SAF 2.1.0, not committed or published.
- Prior checkpoint: `28ede113f679e9f0d2e4f43895d875d696231196` (SAF 2.0.0). This feature supersedes the pending 2.0.1 release preparation, retaining its audit-scope and bootstrap-location corrections.

## Cause and configuration boundary

Project preferences previously lived in shared rules or session instructions, and the proposed configuration file had not been implemented. This mixed reusable SAF policy with this repository's workflow and gave scripts no common typed reader.

Added project-owned `SAF.config.json`, a strict shared `Resolve-SafConfig` reader, and a neutral `templates/SAF.config.json` consumer seed containing only numeric `schemaVersion: 1`. Existing consumer config bytes survive initialization, synchronization, and Force. Source-project preferences never become consumer defaults.

| Source-project setting | Value and consumer |
| --- | --- |
| `origin.repository/ref` | Current SAF repository and `main`; source selection uses explicit arguments, then config, then recorded provenance |
| `project.name` | SAF; project context for the Agent |
| `project.protectedPaths` | Both README files; handlers reject writes to protected files/directory prefixes, including under Force |
| `project.verification` | Deny Computer Use tests and require existing explicit automated-test authorization; consumed by Agent workflows |
| `project.delivery.commit` | Ask for a commit decision; this is not commit authorization |
| `project.records.timeZone` | America/Sao_Paulo for Agent records; operational logs/state remain UTC |

Absent project preferences inherit verification restrictions, require explicit commit authorization, and use UTC records. English, monthly SAF structural auditing, root-script limits, ownership, and payload/path integrity remain fixed standards. `AGENTS.md` remains the instruction entry point; config supplies data, while `SAF.json` supplies release inventory and `SAF.lock.json` supplies observed state. Invalid/unknown fields and invalid types are rejected.

Handlers enforce protected paths and configuration-snapshot checks before writes. Recovery/state helpers share the same checks. Lease cleanup also checks both original and current protection sets before removing an idle legacy lock. A later review moved empty-backup protection ahead of directory creation. Agent preferences do not pretend to control unrelated external sessions or authorize actions.

## Runtime layout and compatibility

Logs, backups, and the operation lease now use `.agents/saf_log/`, `.agents/backup/`, and `.agents/operation.lock`. Skills remain maintained content under `.agents/skills/`; backups retain skills/config and exclude recursive runtime data. Ignore rules cover only runtime paths. Source-only initialization remains `scripts/init.ps1`.

Bootstrap and non-Check origin/local operations migrate legacy `.agent/` storage under old/new lease coordination. Copies are byte-verified before old sources are removed. Different backup collisions stop without replacing either copy; different log collisions receive a hash-suffixed legacy path. Unknown legacy content is preserved. Check never migrates and retains its log-only write exception.

This repository's one existing legacy log was migrated and byte-verified. Framework state and skill hashes were unchanged; the old empty lock and `.agent/` directory were removed. No backup data existed there to migrate. Runtime migration is local and ignored by Git.

The prepared release declares handler protocol 2 and configuration-support version 1. Incompatible handlers request trusted bootstrap recovery; bootstrap rejects sources without declared configuration support. This avoids silently deploying a controller that ignores configured protections. No software, package, runtime, global policy, or Git remote was changed.

## Executed verification

- User-authorized native Windows PowerShell 5.1 suite: all 68 integration checks passed in disposable local Git repositories using the ordinary user temporary directory.
- Covered initialization/error propagation, strict invalid-config rejection, neutral seeding, consumer config retention, source/ref precedence, update/Force protection, compatibility failures, managed conflicts/recovery, state preservation, local backup/archive/ignore, BAT fallback without PowerShell 7, legacy import, runtime migration/collisions, protected legacy lock retention, and linked-storage refusal.
- After the suite, the additional empty-backup preflight guard passed a focused native 5.1 regression proving that a protected backup directory is not created. The full suite was not repeated for that isolated guard change.
- Final maintained-script parsing passed on PowerShell 5.1 and 7. Release inventory/hash and diff checks passed. SAF structural checks are separate from these functional results and do not certify project facts.
- The SAF structural audit passed for 23 payload targets, eight required directories, three skill packages, and 51 local file/heading references. The shared state writer recorded version 2.1.0 completion at `2026-11-12T19:40:04Z`, preserving null source bootstrap/installation and the prior question state. No business-code, architecture-fact, or dependency-fact audit was performed.
- No Computer Use, network bootstrap, actual Downloads redirection, interactive double-click verification, semantic compression, other-platform execution, or exhaustive concurrency/crash testing was performed. Config changes during arbitrary external concurrent edits and Agent preference behavior still need manual acceptance.

## Manual acceptance and delivery

1. After publication, initialize a disposable repository through the trusted remote `scripts/init.ps1` using `irm | iex`; confirm the minimal config and five handlers, then Check/Sync.
2. Change project source/ref and a protected managed path; confirm precedence, rejection under Force, preserved config, and actionable recovery messages.
3. Double-click origin/local/debug and verify menus, waits, cancellation, and actual Downloads redirection. Review backup inventory and ignored runtime paths.
4. In a fresh Agent session, confirm configured test authorization, commit prompting, English documents, and the project record time zone through `AGENTS.md`.

Neither README was edited. The user still needs to update old bootstrap URLs/examples to `scripts/init.ps1`, document the configuration boundary/new runtime paths, and publish only after review. Prior records remain append-only. No new commit, tag, push, or remote rename was performed.
