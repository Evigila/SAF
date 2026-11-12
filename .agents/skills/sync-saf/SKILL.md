---
name: sync-saf
description: Initialize, check, or update SAF in an existing Git repository when the user requests framework synchronization or a version check. Does not perform project-documentation audits.
---

# Synchronize SAF

Read the target's `AGENTS.md`, [synchronization rules](../../../docs-ai/common/rules.md#framework-synchronization), `SAF.json`, and `SAF.lock.json` when present. Separate bootstrap provenance, payload installation, and audit evidence.

- For a version-only request, run `origin.bat -check`. Exit `0` means current, `2` update available, `3` local conflict, `4` bootstrap refresh required, and `1` error. Check may append `.agent/saf_log/` only; it does not update framework files, manifest, or lock. Report the result without applying an update.
- For an authorized update, run `origin.bat -sync` to check then update from the same resolved snapshot, or `origin.bat -update` for the requested selected release. Explicit actions do not wait for input. Reuse existing authorization.
- Apply a requested source/ref through supported `-Repository`/`-Ref` options. Preserve the selected source in installation state without changing the consumer's Git remote.
- Inspect conflicts before proceeding. Use `origin.bat -update -force` only when replacement of managed customizations is authorized. Isolated Force is invalid; seeds and project-owned files remain protected.
- If handlers are missing/incompatible, use trusted source `init.ps1` with the target Git root. It refreshes all handlers with backups and leaves payload synchronization separate. Do not delete the consumer lock or hand-edit its baselines. Do not claim an unpublished remote URL works.

Verify actual differences, installation version/source commit/manifest digest/baselines, and backup references. Confirm project facts, human documentation, user-added skills, debug customization, Git index, and Git origin were preserved. Bootstrap/synchronization does not complete an audit; a version change makes it due under the gate.

Report changed paths, actual verification, conflicts/recovery, and remaining work. Follow static-only/manual-testing constraints instead of executing functional commands. Do not install software, commit changes, or refresh audit completion as part of synchronization.