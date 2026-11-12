# SAF configuration validation and recovery repairs

- Recorded: 2026-11-13 08:48:11, America/Sao_Paulo (UTC-03:00).
- Status: implemented; prepared patch 2.1.2; user-run functional verification pending.
- Authorization: the user requested repairing the four findings in the [generality review](../saf-generality-review.md).

## Repairs and causes

| Finding | Cause | Implemented repair |
| --- | --- | --- |
| R1 recovery overwrites external data | All preflight snapshots were restored, including untouched paths, without ownership of current bytes | Track mutation attempts and actual atomic commit receipts; recover only committed eligible results in reverse order. Check raw before/after hashes and both original/current protections, preserving external or protected changes with a manual-review warning |
| R2 automatic backup omits config | Existing seed config never entered origin's operation-derived backup paths | Explicitly include `SAF.config.json` in origin's automatic recovery scope, matching init/manual backup |
| R3 root arrays accepted as objects | PowerShell enumerated a singleton root array before object validation | Check the JSON root token before parsing in core, bootstrap's independent reader, and publisher. Require an object; retain nested arrays and literal JSON strings across supported PowerShell editions |
| R4 protected ancestors can be created | Only the final child path was checked before parent-directory creation | Validate all missing ancestors against exact and directory-prefix protections before creation. Reject existing-directory/file trailing-slash mismatches without converting exact file rules into subtree rules |

The config resolver now derives its raw hash and parsed policy from one byte read. Transaction snapshots also use one read for original bytes/hash and are rechecked before each mutation. Writes use preflight-selected Create/Replace modes, so a new target is never converted into replacement merely because another writer created it, and replacement does not recreate a disappeared target. Delete operations do not create parent directories. Recovery of deleted files uses create-only restoration; recovery of replaced files uses replace-only restoration.

The atomic helper's optional commit reference distinguishes failure before commitment from an exception after a successful atomic operation. A matching hash alone is not treated as evidence that this transaction wrote an externally created file. Only relevant committed journal entries are considered for recovery, and retained/changed paths are reported. Empty-file snapshots remain distinct from originally absent files.

## Verification and records

Added isolated fixtures for external config/untouched changes, later edits to written files, expected-hash refusal, committed-then-thrown failures, precommit identical external bytes, deleted-empty restoration and external recreation, config bytes in Sync/Force backups, non-object roots at all entry points, protected export ancestors, and protected missing coordination directories. Fixture wrappers stay in child test processes; production code has no test hook.

Only static inspection, PowerShell parsing, release/hash checks, and bounded SAF structural checks are performed in this task. The functional fixture suite is deliberately left for the user under the current verification instruction; the prior 68-check 5.1 result remains evidence for the preceding implementation only. See the [manual regression checklist](../saf-configuration-regression-checklist.md) for commands, expected outcomes, and limits. Any structural-audit completion records current files/formats, not runtime success.

The previous report-name correction and generality-rule clarifications are retained. Reports continue to use descriptive names without the reserved template `1_` prefix. Current documentation now distinguishes implemented repairs from pending behavioral verification; prior append-only records remain unchanged. Neither README, source project config, nor dependencies were changed. No new runtime, package, network retrieval, Computer Use, commit, tag, or push is part of this repair task.

File operations still have check/write windows against arbitrary external concurrency; these changes are not a global filesystem transaction or power-loss guarantee. Recovery can retain paths for manual review when current policy/content prevents safe restoration.

Final static evidence: maintained PowerShell files and both embedded fixture scripts parsed successfully with PowerShell 5.1 and 7; the 2.1.2 manifest/payload hashes and diff whitespace checks passed. Bounded structure checks verified 23 payload targets, eight required directories, three skills, and 75 current/affected local references. The shared writer recorded structure-only audit completion at `2026-11-13T11:54:13Z`, preserving null source bootstrap/installation and prior question state. README hashes and source project config remain unchanged. These results do not mean the new functional fixtures have been run.
