# SAF configuration and recovery regression checklist

## Status and scope

The formal SAF 2.0.0 release target incorporates the four repairs from the [generality review](saf-generality-review.md) and uses project configuration schema 2, handler protocol 3, and config support version 2. Release and lock schemas remain 1. The coordinator completed fresh `tests/test-saf.ps1` runs for 2.0.0 in Windows PowerShell 5.1 and existing PowerShell 7, with the results below. Earlier 3.0.0-label runs remain unpublished preparation history. The checklist is retained for repeatable verification. Static parsing and inspection alone do not establish runtime success.

No new software or PowerShell module is required. The fixture suite copies the current working payload into temporary Git repositories, creates only fixture commits, and does not change the source repository's index, origin, or commit. It uses local Git sources instead of a network release. Run from an ordinary terminal with a reasonably short temporary-directory prefix; earlier .NET Framework runs encountered long-path limits inside the application's sandbox.

## Completed fixture runs and repeat commands

Recorded on 2026-11-13 at 11:36, America/Sao_Paulo (UTC-03:00), using fresh isolated SAF 2.0.0 fixtures under ordinary user TEMP. Both runs include schema/default/UI/commit values, removed-field rejection, and all R1-R4 regressions. These are new 2.0.0-target results, separate from the earlier unpublished 3.0.0 preparation label. No Computer Use, live network initialization, or other-platform runtime testing was performed.

| Fresh 2.0.0 run | Result |
| --- | --- |
| Windows PowerShell 5.1, SAF 2.0.0 | All 152 checks passed; exit 0 |
| Existing PowerShell 7 on Windows, SAF 2.0.0 | All 148 checks passed; exit 0; four Desktop-only fallback checks omitted |

The SAF structural audit completed at `2026-11-13T14:36:34Z` for version 2.0.0, checking 23 payload targets, eight required directories, three skill packages, and 72 local file references. Structural completion remains separate from functional fixtures and does not certify application facts or Agent behavior.

From this source repository root, run the existing Windows PowerShell host:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\test-saf.ps1
```

If PowerShell 7 is already available, run it separately:

```powershell
pwsh.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\tests\test-saf.ps1
```

These policy arguments affect only the child process. Use `-KeepFixtures` to retain successful fixtures for inspection; failures print and retain their fixture location. Do not infer success for one edition from the other. Record actual exit codes and the suite's reported check count after execution.

## Required behavior checks

| Area | Trigger and required outcome |
| --- | --- |
| Schema and compatibility | Missing config seeds only `{ "schemaVersion": 2 }`; manifest/lock remain schema 1. Accept framework >=2.0.0/protocol 3/support 2. Existing schema 1 is rejected before bootstrap writes, with explicit migration guidance and original bytes preserved |
| Current configuration | Accept origin, protected paths, Computer Use, UI framework, and commit-style settings. Reject removed project-name, automated-test, delivery-approval, and record-time-zone keys rather than silently retaining them |
| Shared defaults | Resolve absent optional settings to Computer Use `deny`, UI `Material Design 3`, commit style `follow-history`, and initial style `english-imperative`; no source-specific origin or protected paths are injected |
| Unwritten targets and config | Inject an external config creation and a change to a not-yet-written target after the first transaction write. The transaction must abort, restore its eligible first write, and preserve external config/target bytes |
| Later external edit | Change a file after the transaction wrote it, then abort. Recovery must retain/report the external bytes rather than restore the original snapshot over them |
| Commit receipt | Inject an exception after the atomic replacement committed: recovery must restore the original. Inject a failure before commit after externally writing identical bytes: recovery must not claim those bytes as its own |
| Deleted empty file | Delete an existing zero-byte file, then fail a later write. Recovery must recreate the empty file. If it was externally recreated, recovery must retain that external file |
| Recovery configuration | Trigger initial Sync, compatible Sync, and Force replacement. Every newly created origin recovery point must contain `files/SAF.config.json` and an inventory entry with its original exact bytes; live config must remain unchanged |
| JSON roots | Replace config, lock, manifest, and neutral seed with a singleton-array wrapper or a primitive root. The appropriate origin/bootstrap/publisher path must reject it; malformed source payloads must not be installed. Normal object roots with nested arrays such as `protectedPaths` remain supported |
| Missing protected ancestor | In a disposable consumer with a nonempty archive, configure `protectedPaths: ["exports"]` while that path is absent. Export to `<consumer>/exports`; it must fail before creating `exports`, preserving archived files |
| Coordination ancestor | In a disposable root without `.agents`, protect exact `.agents`. A state write must fail before creating `.agents`, its lease, or `SAF.lock.json` |
| Protection type | Configure an existing directory without its trailing `/`, or an existing regular file with `/`. Resolve must report the mismatch. Correct trailing-slash directory protections must still cover descendants, including under Force |
| Ordinary operations | Confirm valid initialization, Check's log-only write boundary, successful Sync/Force, local backup/archive export, unchanged consumer facts/custom skills/debug menu, and preserved Git index/origin |

Fault injection belongs only in isolated fixture child processes. The suite wraps the already-loaded atomic function there; production controllers contain no test hook. A real user session must not be paused or edited experimentally to test rollback.

## Acceptance limits

These repairs use explicit create/replace modes, commit receipts, raw-byte checks, and both original/current protections during recovery. They reduce the identified overwrite paths; they do not provide an operating-system compare-and-swap transaction against arbitrary concurrent external writes or process/power failure. Preserve recovery warnings and inspect retained paths before retrying.

Live remote `irm | iex`, redirected Windows Downloads, interactive menus, and fresh-session Agent preferences remain separate manual acceptance from these local fixtures. Confirm that implementation tests are required within task limits, commits are approved before creation, existing commits are preserved, and style preferences affect presentation only. UI guidance must not automatically install or adopt a library. Operational timestamps stay UTC; project record time zones are not configured here. Neither script repairs nor fixture success certify business code, architecture facts, or dependency facts.
