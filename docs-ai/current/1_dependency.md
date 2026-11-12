# SAF dependency inventory

## Scope and evidence

This inventory covers the SAF 2.0.0 source and distributed Windows handlers. Evidence: `init.ps1`, `origin.bat`, `local.bat`, `debug.bat`, `scripts/origin.ps1`, `scripts/local.ps1`, `scripts/saf-core.ps1`, `scripts/publish-saf.ps1`, `tests/test-saf.ps1`, and `.github/workflows/verify.yml`.

There are no package-manager manifests, application projects, NuGet/npm packages, project references, fonts/icons, databases, or deployed application services. SAF uses existing tooling and built-in .NET libraries; no third-party PowerShell modules, Pester package, external compressor, global CLI, service, or model-engine adapter is installed. Skills require an existing Agent capable of reading/executing their instructions; SAF does not provision one.

## Tools, runtimes, and services

| Dependency | Declared constraint / observed evidence | Relationship, consumers, and scope | Purpose |
| --- | --- | --- | --- |
| Git | Existing Git on PATH; no project minimum pin. Inspection shell observed `2.56.0.windows.4`. | Direct bootstrap/synchronization, tests, development | Resolve Git root and exact commit; acquire manifests/regular blobs; create disposable test fixtures. Never reconfigure the consumer origin/index/branch/commits. |
| Windows CMD | Existing Windows `cmd.exe`, OS component | Direct user-facing origin/local/debug BAT entry points | Thin launchers, visible interaction, and isolated child BAT dispatch |
| Windows PowerShell / PowerShell | Scripts require version 5.1; Windows PowerShell `5.1.26100.9818` passed the 34-check fixture suite. PowerShell `7.6.9` was observed and statically checked, not functionally verified in this task. | Direct bootstrap, handlers, publisher, tests | Built-in Git process orchestration, JSON, filesystem, and remote bootstrap retrieval |
| .NET runtime/framework | Supplied by selected PowerShell; tested 5.1 host reported `.NET Framework 4.8.10008.0`, inspection shell reported `.NET 10.0.14`. No independent project pin/install. | Transitive runtime of PowerShell; used by handlers/publisher/tests | UTF-8, SHA-256, streams, processes, atomic file replacement, file leases, and ZIP entry/content verification |
| Built-in .NET compression libraries | System.IO.Compression APIs supplied by PowerShell's .NET environment | Direct library use, local archive export and fixture/archive processing | ZIP generation/readback with explicit hidden-file traversal; no external ZIP executable |
| Windows per-user shell-folder configuration | User Shell Folders registry key and Downloads GUID `{374DE290-123F-4565-9164-39C4925E467B}`; unversioned OS contract | Direct local archive export on Windows | Resolve redirected Downloads path rather than assume a profile subdirectory; explicit destination is a script option |
| GitHub Git/HTTPS and raw content | Current default source `https://github.com/Evigila/AGENTS.md.git`, default ref `main`; exact installed commit is recorded locally | Direct remote bootstrap/synchronization service; not needed for offline local operations | Published init retrieval and release data acquisition. A future `Evigila/SAF` URL is not assumed available. |
| Existing Agent environment | No vendor, model, package, or version fixed by SAF | External host for the three instruction skills | Execute sync, project-documentation audit, or semantic memory compression in a current Agent session |
| GitHub Actions | Hosted Windows/Linux runners, provider-managed versions | CI only | Default hash/parse matrix; integration only through explicit workflow dispatch |
| `actions/checkout` | Commit pin `11d5960a326750d5838078e36cf38b85af677262` (`v4` label in workflow); shallow source checkout | Direct CI action dependency | Retrieve maintained source for validation |
| Node.js action runtime | `node20` declared by that pinned checkout action, from the prior recorded declaration inspection; supplied by Actions, not installed by SAF | Transitive CI runtime | Execute the checkout action; not a local handler/skill requirement |

The checkout action ships bundled JavaScript; this repository neither installs nor resolves its internal development package graph. OS/provider implementation dependencies are not independently pinned project packages. There is no application-package resolution graph or local project-reference inventory to enumerate.

## Sources and licensing

The framework source is MIT-licensed in `LICENSE`. No Git, PowerShell, .NET runtime, or compressor binary is redistributed. Their licenses follow the installed OS/distribution. GitHub services follow platform terms.

The pinned checkout action declaration and MIT license were recorded as inspected in the prior inventory at [its fixed action revision](https://github.com/actions/checkout/blob/11d5960a326750d5838078e36cf38b85af677262/action.yml) and [license](https://github.com/actions/checkout/blob/11d5960a326750d5838078e36cf38b85af677262/LICENSE). This upgrade did not fetch or revalidate remote licensing. Exact rolling CI image/tool versions are unresolved until a workflow run supplies its log evidence.

## Boundaries and unresolved verification

The dependency changes are a redistribution of existing built-in capabilities, not installation of new software. The old curl-based download is replaced by PowerShell `irm` bootstrap guidance; curl is not a SAF 2 requirement. Proprietary namespace/UI defaults and a mandatory NuGet publication slot are removed; project-specific debug operations may use any already authorized toolchain.

Windows BAT/Downloads behavior requires Windows. The Linux CI configuration parses PowerShell and can run explicitly requested applicable fixtures; it does not establish Windows shell integration or universal OS support. User-authorized Windows PowerShell 5.1 verification passed all 34 integration checks, including BAT fallback without PowerShell 7 and archive export/cleanup to a supplied disposable destination. The tested .NET Framework host hit a path-length limit under the sandbox's unusually long temporary prefix; normal-temp verification passed. No remote endpoint publication, live network bootstrap, actual Downloads redirection, semantic compression, PowerShell 7 functional suite, or other-platform runtime was verified. See [5.1 verification](1_changelogs/2026-11-12_115748_powershell-51-verification.md) and the prior [implementation record](1_changelogs/2026-11-12_113446_saf-2-upgrade.md) for scope and remaining manual checks. The declared 5.1 minimum is unchanged, and no runtime was installed or upgraded.
