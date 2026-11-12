# Windows PowerShell 5.1 verification

- Record opened: 2026-11-12 11:57:48, America/Sao_Paulo (UTC-03:00).
- Release under preparation: SAF `2.0.0`; no public release, commit, or tag was created.
- Follow-up to [the implementation record](2026-11-12_113446_saf-2-upgrade.md).

## Authorization and scope

The user explicitly authorized functional testing under Windows PowerShell 5.1. The instruction to leave both README files to the user remained effective. Tests used disposable local Git repositories and did not perform live network bootstrap, change the real repository's index/origin, install software, or use Computer Use.

## Results

On Windows PowerShell `5.1.26100.9818` / `.NET Framework 4.8.10008.0`, all **34 explicitly requested integration checks passed** after the corrections below. The publisher's read-only release validation also passed under that edition. This supersedes the earlier static-only verification status for the covered scenarios, without rewriting the append-only implementation record.

Coverage includes bootstrap-only deployment, nonzero bootstrap failure status, Check's log-only exception, invalid action flags, Sync/Update, exact commit recording, audit/installation preservation, zero-byte rollback, version preparation, committed customization, Force byte backups, seed/project protection, invalid payload/protocol rejection, forged migration ownership rejection, reinitialization, local backup/ignore, verified hidden-content ZIP cleanup, and legacy state import. Consumer Git-state protection is checked by assertions within the suite.

The BAT fallback checks remove directories containing `pwsh.exe` from child-process PATH only. The suite verifies PowerShell 7 cannot be resolved there, then successfully runs origin Check, local Backup, and debug cancellation. Default wrappers may otherwise choose an already available PowerShell 7; those default-path checks alone would not prove the 5.1 fallback works.

Tests used process-local execution-policy arguments; no machine/user policy, system PATH, Defender setting, or exclusion was changed. Normal test runs used the real Windows temporary directory because the execution sandbox's unusually long temporary prefix caused the path failure described below. The successful suite cleaned its own bounded fixtures. Earlier failed fixtures were retained for diagnosis.

## Corrections

- `init.ps1`: wrap the internal initialization block in a file-level catch/rethrow. A nested initialization failure previously printed an error while the process returned zero. The fix preserves failure status without using `exit` in evaluated bootstrap code or changing the caller's error preference. Added a nonzero-exit regression assertion.
- `scripts/local.ps1`: calculate the default project root in the script body rather than in parameter-default binding. The forced-5.1 BAT test observed an empty `$PSScriptRoot` during parameter binding. Explicit `-ProjectRoot` calls had already passed.
- `scripts/origin.ps1`: move the equivalent default-root calculation into the body too, retaining explicit-root precedence and the launcher's process-local root.
- `tests/test-saf.ps1`: allow child-only environment overrides and add the PowerShell-7-absent BAT checks. Reviewed that local no-argument menu detection still uses the original bound-parameter count.
- `SAF.json`: refreshed hashes for the changed managed scripts within the still-unreleased `2.0.0` preparation. No dependency or minimum-version requirement was changed.

## Limits and delivery

The first sandbox run hit a `PathTooLongException` while creating nested recovery paths. The same suite passed in the normal Windows temporary directory after correcting the unrelated failure-status bug. This is an observed 5.1/.NET Framework host limitation for long paths; the result does not promise support for arbitrary path lengths. No equivalent long-path PowerShell 7 test was performed.

No live `irm` pipeline, published remote update, actual redirected Downloads selection, interactive double-click flow, full debug operation, or semantic Agent skill execution was validated. The archive scenario supplied a disposable output destination. Those remain manual/platform checks. Both README hashes remained identical to their values before this task; the user retains their maintenance.

The tested normal-path behavior supports retaining the declared 5.1 minimum. A general PowerShell 7+ requirement is not established by these results. Detailed diagnosis is in [the bug report](../1_bugreports/2026-11-12_115748_powershell-51-bootstrap.md).
