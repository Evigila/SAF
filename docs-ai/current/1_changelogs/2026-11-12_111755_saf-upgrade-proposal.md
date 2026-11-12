# SAF upgrade proposal

- Date: 2026-11-12 11:17:55, America/Sao_Paulo (UTC-03:00).
- Scope: Analysis of the requested transition to Simple Agent Framework; implementation remains pending.

## Requirements and clarification

The user requested remote `init.ps1` bootstrap, `origin.bat` remote management, `local.bat` maintenance, SAF metadata names, combined installation/audit state, command logs, `sync-saf`, and `debug.bat`. The supplied shared conversation explicitly retains Git as a prerequisite. During this analysis, the user clarified that audit and semantic compression should be skills and should not be `local.bat` operations. Preserve the requested meaning of `-sync`: check followed by update when available.

## Documentation

Added [the SAF upgrade proposal](../1_saf-upgrade-proposal.md), distinguishing user requirements from recommended defaults and unimplemented work. It covers usable handler bootstrap, independent recovery for breaking protocols, state-section ownership, archive/ignore semantics, logging versus check-write guarantees, generic-policy changes, migration scope, and manual acceptance checks.

No executable files, active shared rules, manifest, dependency declarations, or audit state were changed in this step. Previous analysis/audit changes already in the working tree were preserved.

## Verification and limits

Read the full supplied conversation in the browser and compared relevant claims with the local synchronization source. Consulted official PowerShell, Git ignore, archive, and Windows Known Folder documentation. Reviewed the proposal for link destinations and whitespace; no functional tests or Computer Use tests were performed. All proposed commands and schema changes remain unimplemented.
