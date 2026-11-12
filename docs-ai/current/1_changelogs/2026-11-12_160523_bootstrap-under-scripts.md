# Move the source bootstrap under scripts

- Record opened: 2026-11-12 16:05:23, America/Sao_Paulo (UTC-03:00).
- Release preparation: SAF 2.0.1, including the preceding uncommitted audit-scope correction.
- Baseline checkpoint: `28ede113f679e9f0d2e4f43895d875d696231196`.

## Cause and changes

The source-only root `init.ps1` needed an exception to the framework's root-script restriction. The user requested removing that exception by placing the bootstrap at `scripts/init.ps1`.

Moved the bootstrap without leaving a root compatibility script. Target selection still uses the caller's filesystem working directory or explicit `-ProjectRoot`, not the bootstrap's own folder. The bootstrap remains source-only and is not added to the five installed handlers or payload manifest.

Updated the shared script-location contract, synchronization skill, architecture/dependency references and template, recovery messages, test source packaging, and CI script discovery. CI now discovers all maintained PowerShell scripts under `scripts/` and `tests/`. Tests use the relocated bootstrap and assert that neither the source fixture nor installed consumer retains a root init script.

The pending 2.0.1 release was not previously committed or published; its payload hashes were refreshed to include these related corrections. Handler protocol 1, metadata schemas, command contracts, English, monthly SAF-only structural auditing, root BAT entry points, and dependency requirements remain unchanged. No configuration file or additional rule entry point was introduced.

## Verification

- Release-manifest/hash validation, PowerShell 5.1 and 7 syntax parsing, and diff whitespace checks passed.
- The user-authorized Windows PowerShell 5.1 disposable-repository suite was rerun against the relocated bootstrap and prepared 2.0.1 payload: all 34 integration checks passed. Additional packaging assertions confirm the root bootstrap is absent. This is a new run, distinct from the prior 2.0.0 result.
- Checks include local-source initialization, nonzero failure propagation, synchronization, reinitialization, conflict/Force protection, state preservation, local maintenance, legacy import, and BAT operation with PowerShell 7 absent from child PATH.
- Tests used the normal Windows temporary directory and process-local policy/environment options only. No global PATH, execution policy, or protection setting was changed; no Computer Use was used.

Live network bootstrap, published endpoint availability, actual Downloads redirection, and interactive double-click flows remain unverified. PowerShell 7 received static parsing only. Failed long-path-host limits from earlier evidence remain applicable.

## README and delivery

The user retains README ownership; neither README was edited. Their old `/main/init.ps1` bootstrap URLs and root-local examples are now stale. After this version is published, the remote path must use `/main/scripts/init.ps1`, and local source invocation must point to `scripts/init.ps1`. There is intentionally no root forwarding file. Historical/archived records retain their original paths as history.

No commit, tag, push, or remote repository rename was performed for this correction. The existing 2.0.0 checkpoint remains available; this work and the preceding 2.0.1 rule correction remain pending review/commit.
