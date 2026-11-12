# PowerShell 5.1 bootstrap and default-root failures

- Date: 2026-11-12, America/Sao_Paulo (UTC-03:00).
- Status: Failure propagation and default-root defects corrected; long-path host limitation remains.
- Evidence: Actual Windows PowerShell `5.1.26100.9818`, `.NET Framework 4.8.10008.0`, and disposable Git fixtures. See [verification results](../1_changelogs/2026-11-12_115748_powershell-51-verification.md).

## Symptoms and diagnosis

1. In the execution sandbox, the bootstrap child returned exit zero but the fixture lacked `origin.bat`. Inspecting the child output in the same sandbox invocation revealed `PathTooLongException` from directory creation. The temporary prefix plus fixture, consumer, recovery timestamp/ID, and payload subpath exceeded the tested .NET Framework path limit. Successful process status therefore was not evidence of successful initialization.
2. The bootstrap's error preference was scoped inside an invoked script block. Without a file-level catch/rethrow, the failure could be reported at the outer invocation without causing the expected failed `-File` exit. This propagation defect was not specific to PowerShell 5.1.
3. A subsequent normal-temp run passed 30 checks. Additional BAT tests hid PowerShell 7 in the child PATH and exposed local backup failing during parameter binding: `Split-Path -Parent $PSScriptRoot` received an empty string. Earlier local tests explicitly supplied `-ProjectRoot`, and the ordinary BAT could choose PowerShell 7, so neither exercised that failure path.

## Fix and mitigation

Init now catches/rethrows at file scope, keeping evaluated bootstrap free of a process-exiting `exit`. Local computes its default root in the script body; origin applies the same treatment while preserving explicit-root and launcher-root precedence. Test environment overrides are child-local and do not change system settings.

Use reasonably short project/temporary paths with the tested Windows PowerShell/.NET Framework host. There is no claim that arbitrary long paths were repaired, nor that PowerShell 7 was tested against the original failing long-path case.

## Regression evidence

The final Windows PowerShell 5.1 run passed all 34 integration checks, including explicit bootstrap-failure propagation and origin/local/debug BAT fallback with no resolvable `pwsh.exe`. The suite also asserts zero-byte rollback preservation and protected Git/project state. No source README was edited, no security protection was disabled, and no global runtime or configuration was installed or changed.

Live network bootstrap, actual Downloads redirection, interactive menus, all debug actions, and semantic skills remain unverified. Failed diagnostic fixtures are retained; a passing run removes only its own verified temporary root.
