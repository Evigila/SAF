# SAF generality and configuration review

## Scope and result

Reviewed on 2026-11-13, America/Sao_Paulo (UTC-03:00), against implementation checkpoint `47785cf9bc7f0ab268817f512891e3f728cbead9`. Scope: the instruction router, shared rules, templates, skills, BAT entry points, PowerShell controllers/core/publisher, source configuration, manifest, and relevant existing fixture coverage. Three bounded reviewers independently checked rules, synchronization/bootstrap, and local/core behavior.

The core no longer imposes a consumer product name, organization namespace, UI library, NuGet ecosystem, or Brazilian record time zone. Project preferences are separate from the neutral consumer seed. The actual source `SAF.config.json` was loaded read-only through `Resolve-SafConfig` and returned its configured values. Four implementation gaps were identified at this checkpoint. Their diagnosis is retained below; the subsequent implementation status is separate from that original evidence.

The original review corrected report names and clarified shared documentation without repairing scripts or rerunning functional fixtures. Its unpublished 2.1.x preparation configuration and diagnoses remain historical evidence. The formal release target is SAF 2.0.0/config schema 2/handler protocol 3/config support 2, incorporating the four repairs below. The preceding 68-check 5.1 run remains historical evidence with its original scope. Fresh SAF 2.0.0 fixtures passed 152 checks in PowerShell 5.1 and 148 in existing PowerShell 7, both exit 0, as recorded below; earlier 3.0.0-label runs were unpublished preparation evidence.

## Current implementation status: SAF 2.0.0 release target

All four checkpoint findings have implementation changes incorporated into the SAF 2.0.0 release target. Recorded on 2026-11-13 at 11:36, America/Sao_Paulo (UTC-03:00): the coordinator completed fresh isolated SAF 2.0.0 fixture runs under ordinary user TEMP. Windows PowerShell 5.1 passed all 152 checks, exit 0; existing PowerShell 7 passed all 148 checks, exit 0. PowerShell 7 omits four Desktop-only fallback checks. Both runs include schema 2, current defaults/UI/commit values, removed-field rejection, and R1-R4. Earlier 3.0.0-label runs remain unpublished preparation history, separate from these fresh results. No Computer Use, live network initialization, or other-platform runtime testing was performed. See the [fix record](1_changelogs/2026-11-13_084811_config-recovery-fixes.md) for repair history and the [regression checklist](saf-configuration-regression-checklist.md) for repeatable checks.

| Finding | Implemented change | Fresh 2.0.0 fixture verification |
| --- | --- | --- |
| R1: recovery ownership | Single-read config/snapshots; per-mutation preflight rechecks; atomic create/replace selected from expected existence; commit receipts; reverse recovery only for committed, still-matching results, under original and current protections | Controlled recovery/failure scenarios passed in the fresh 5.1/7 runs |
| R2: config recovery snapshot | Origin automatic backups explicitly include existing project config and its exact bytes/hash even when no config write is planned | Configuration backup/Force regression passed in both fresh runs |
| R3: JSON root shape | Core, pre-core bootstrap, and publisher require a lexical object root and a parsed object before schema validation; config hash and parsing share one byte read | Malformed-root regressions passed in both fresh runs |
| R4: protected ancestors/types | Validate the target and all missing ancestors before directory creation; reject existing directories without trailing slash and files with one | Protected ancestor/type regressions passed in both fresh runs |

An attempted write is not a commit: the helper reports commitment immediately after a successful Move/Replace, so a subsequent exception can recover that operation without claiming a write that failed before commitment. Recovery uses raw-byte hashes, preserves unexpected external content, and warns when policy or path changes prevent restoration. This narrows the reported failure cases; it is not a filesystem sandbox or a guarantee against arbitrary external races and power loss.

## Current configuration and fixed standards

The neutral consumer seed is `{ "schemaVersion": 2 }`. Release and lock schemas remain 1. Source-specific origin and README protections remain in the source config; they are not consumer defaults. Computer Use testing defaults to `deny`, UI guidance defaults to `Material Design 3`, and commit presentation defaults to `follow-history` with `english-imperative` as the initial fallback. UI guidance is an Agent preference and does not install or authorize any UI library.

| Current field | Reader and effect |
| --- | --- |
| `origin.repository/ref` | Origin/init source selection: explicit arguments, config, then recorded provenance; init has the distribution fallback |
| `project.protectedPaths` | Shared resolver validates exact files/trailing-slash directories; handlers and Agent work honor protections within applicable authorization |
| `project.verification.computerUse` | Agent uses `deny` by default or `inherit`; applicable explicit user instructions take precedence and neither value grants tool permission |
| `project.ui.framework` | Agent uses the nonempty design-guidance string; default `Material Design 3` adds no package or dependency |
| `project.commit.style` | Agent follows the established repository pattern by default (`follow-history`) |
| `project.commit.initialStyle` | Agent uses the fallback when no established pattern applies; default English imperative subjects |

Appropriate implementation tests are required within the task's authorization and explicit user limits. A Git commit requires approval unless already authorized; existing commits must not be deleted or rewritten. These are fixed standards, not configuration switches. Schema 2 removes project name, automated-test authorization, delivery approval, and record-time-zone fields; it rejects the old keys. Existing local preparation config must be explicitly migrated before the current SAF 2.0.0 initialization and is not overwritten. Operational logs/state stay UTC; record time-zone selection follows applicable shared/session guidance rather than project config.

## Historical project-specific classification at checkpoint 47785cf

The table below records the schema-1 checkpoint assessment. Its source preferences and old default values are retained as diagnosis history, not current schema-2 instructions.

| Content | Assessment |
| --- | --- |
| Source project name, protected README pair, test/commit preferences, and America/Sao_Paulo | Correctly held in source `SAF.config.json`; the consumer template contains only numeric schema version 1 |
| Default `https://github.com/Evigila/AGENTS.md.git` in `scripts/init.ps1` | Remaining literal distribution identity, not a consumer business rule. Init needs a source for first use; explicit arguments/config/provenance override it. A future source rename must update this fallback, release identity/config, and user-maintained usage examples |
| `main` fallback | Overridable source-ref convention, not the consumer repository's branch requirement |
| Windows BAT/Downloads behavior and existing Git/PowerShell | Declared platform/tooling boundaries; no new application installation or project language/ecosystem requirement |
| Debug/clear-database/tag/package seed menu | Generic example operations without a toolchain binding. Projects may customize the seed; missing operations report unconfigured. SAF does not infer that every project has a database or publishes packages |
| English, monthly SAF-only structural audit, root entry limits, and sole AGENTS router | Intentionally fixed standards already confirmed by the user; not missing configuration fields |
| Source publishing/version instructions | Clarified to apply to SAF release maintainers. Consumer customization preserves installed release identity and conflict evidence |

Project-owned scripts launched by `debug.bat` are not automatically filesystem-sandboxed by SAF. The Agent must assess their effects against project protections. Shared wording now distinguishes that boundary from SAF's own write helpers.

## Historical configuration field trace: schema 1

These values were read at checkpoint `47785cf9bc7f0ab268817f512891e3f728cbead9`. The removed fields below are not accepted by the current resolver. Use the current field table above for the SAF 2.0.0 release target.

| Field | Effective source value / default | Reader and effect | Result |
| --- | --- | --- | --- |
| `schemaVersion` | 1 / required when present | Shared resolver validated integer schema 1 at this checkpoint | Historical schema; schema 2 and R3 regressions passed in later unpublished-preparation runs |
| `origin.repository` | Current SAF Git URL / no default in origin | Origin/init select explicit argument, then config, then installation/bootstrap provenance. Init alone has the first-use distributor fallback | Connected to acquisition; no consumer Git remote mutation |
| `origin.ref` | `main` / provenance, then `main` | Same source selection order; explicit arguments override config | Connected to resolved source commit |
| `project.name` | SAF / absent | Agent context/display information | Intentional Agent value; does not replace framework branding or rename consumer identities |
| `project.protectedPaths` | README pair / empty array | Agent restrictions plus SAF core/controller write checks; Force retains checks | Original checkpoint gaps retained below; R1/R4 fixture regressions passed in later unpublished-preparation runs |
| `project.verification.computerUse` | `deny` / `inherit` | Agent reads applicable rules before selecting verification tools | Instruction enforcement, not OS-level process control |
| `project.verification.automatedTests` | `explicit-authorization` / `inherit` | Agent requires existing explicit authorization | Does not launch/block arbitrary external test processes |
| `project.delivery.commit` | `ask` / `explicit-authorization` | Agent asks at applicable delivery; neither mode authorizes a commit | Correct instruction route; cannot mechanically guarantee another Agent's behavior |
| `project.records.timeZone` | America/Sao_Paulo / UTC | Agent-authored records | Intentionally leaves operational logs/audit deadlines in UTC; runtime checks a nonempty string, not a time-zone registry |

At that checkpoint, `project.name` and the verification/delivery/record preferences had documented Agent consumers through `AGENTS.md` and skills. That explains their original classification, not their continued validity: the removed fields are no longer part of schema 2. Current UI and commit-style preferences also require fresh-session Agent acceptance rather than an assumption that a shell branch enforces them. The historical root-array issue had a separate cause and now has the R3 implementation above.

## Checkpoint findings retained as diagnosis

The following descriptions and source-line evidence refer to checkpoint `47785cf9bc7f0ab268817f512891e3f728cbead9`, before the incorporated repairs. They preserve the original diagnosis, including schema-1 examples and old line numbers, not current implementation claims or instructions. Current implementation status and completed fixture results are listed above.

### R1: Transaction recovery can overwrite a file the operation never changed

Evidence: `scripts/saf-core.ps1`, `Invoke-SafTransaction`, lines 403-432 at the reviewed checkpoint. Preflight snapshots every planned path; the catch block restores every snapshot, without recording which operations actually wrote a path or verifying ownership of its current contents.

Trigger: during first initialization, config is absent and its snapshot is null. After preflight, the user creates `SAF.config.json` with protections before the transaction writes that seed. The next config-snapshot check aborts, but recovery can delete that newly created config as though the transaction created it. Existing externally edited, not-yet-written paths can similarly be restored to older bytes. This requires a concurrent edit, but the impact can be loss of user data precisely when a protective check requests an abort.

Recommendation at the checkpoint: journal successfully applied operations and their resulting byte hashes; recover only this operation's writes while retaining/reporting external changes. Also derive config hash and parsed policy from one byte read: the checkpoint's `Resolve-SafConfig` read bytes separately for hashing and parsing (lines 142 and 152), so they could represent different snapshots. Do not treat recovery as permission to overwrite arbitrary new state.

### R2: Origin's automatic recovery snapshot omits existing project configuration

Evidence: `scripts/origin.ps1`, lines 56-64 and 106-107. Existing seeds are skipped; backup paths contain planned operations plus `SAF.lock.json`. Since an existing `SAF.config.json` is never a planned write, it is absent from normal update/sync snapshots. `New-SafBackup` does not add it implicitly. Init and manual local backup explicitly include config.

Trigger: customize a consumer config, then update a release that changes a managed file. The update snapshot inventory and `files/` omit the existing config despite the shared scoped-recovery contract. Synchronization still preserves the live config; the recovery snapshot is incomplete.

Recommendation: explicitly include `SAF.config.json` in origin recovery paths and verify its exact bytes in the resulting inventory, including forced updates.

### R3: Root JSON arrays can lose their shape before object validation

Evidence: `Read-SafJson` in `scripts/saf-core.ps1`, lines 20-23, returns the output of `ConvertFrom-Json` directly; resolver validation occurs after PowerShell output enumeration. A singleton top-level array such as `[{"schemaVersion":1}]` can become its sole object, bypassing the intended root-object check. Publisher template parsing at `scripts/publish-saf.ps1`, line 79, has a corresponding enumeration path. This is an object-shape gap, not a source-project-preference leak by itself.

Recommendation at the checkpoint: validate/preserve the JSON root token before PowerShell pipeline enumeration, using a 5.1-compatible approach. Reject arrays and primitive roots consistently for config, neutral seed, and release/state documents as applicable. Do not depend solely on a PowerShell 7-only option. The original read-only checkpoint review did not execute malformed input; subsequent passing fresh SAF 2.0.0 fixture results are recorded above.

### R4: Exact protected paths can be created as unvalidated ancestor directories

Evidence: `Assert-SafWritable` in `scripts/saf-core.ps1`, lines 218-226, checks the supplied target; a non-trailing-slash entry is an exact match. `scripts/local.ps1`, lines 141-147, checks the future ZIP path, then creates its output directory without checking each missing ancestor.

Trigger: use valid config `project.protectedPaths: ["exports"]`, leave `exports` absent, and export nonempty archives with `-Destination <repo>/exports`. The ZIP child does not equal protected `exports`, so `CreateDirectory` can create the protected path as a directory. Similar parent creation exists in backup, logs, leases, migration, and transactions.

Recommendation: check every actual directory that will be created before creating it. Preserve the distinction between exact file paths and explicit trailing-slash directory prefixes; do not silently broaden every exact file rule into a subtree rule. Clarify/reject an existing directory configured without the required trailing slash to avoid a misleading protection assumption.

## Report naming correction

`1_` belongs to framework-defined template artifacts, including `1_architecture.md`, `1_dependency.md`, and the required history/archive directories. It does not label all AI-authored content. Ordinary reports stay directly under `current/` with descriptive names.

| Previous project-report path | Current project-report path |
| --- | --- |
| `1_framework-analysis.md` | [framework-analysis.md](framework-analysis.md) |
| `1_saf-upgrade-proposal.md` | [saf-upgrade-proposal.md](saf-upgrade-proposal.md) |
| `1_saf-modularity-proposal.md` | [saf-modularity-proposal.md](saf-modularity-proposal.md) |

At the review checkpoint, the archived modularity proposal's active replacement link was updated without changing either README. Append-only change records retain their original text and point-in-time path references; the relocation record supplies links instead of rewriting that history.

## Recommended manual checks

1. In a disposable consumer, compare absent/minimal schema-2 config with a full config; verify no source-specific origin or README paths are injected. Confirm default Computer Use denial, Material Design 3 guidance, and commit-style defaults. Reject schema 1, removed keys, malformed types/unknown keys, and non-object JSON roots in 5.1 and 7.
2. Configure a source/ref different from lock provenance; verify explicit arguments override config, config overrides provenance, and Check leaves payload/state unchanged. Use a published trusted source separately for live bootstrap acceptance.
3. Update and Force-update a managed file; inspect automatic backup inventories for exact-byte config and original conflict content. Compare init/manual snapshots.
4. Try exact protected files, trailing-slash directories, and a missing exact path used as an archive-output ancestor. Verify refusal before that protected path is created, and confirm existing contents remain intact.
5. In an isolated fixture with a controlled pause after transaction preflight, create/edit config and another not-yet-written target; let the operation abort. Verify external bytes survive recovery. Recheck normal rollback after injected write failure separately.
6. In a fresh Agent session, verify default Computer Use denial, required implementation testing within task limits, commit approval and preserved existing commits, English prose, and configured UI/commit presentation. A UI preference must not trigger a library installation. Record timestamps follow applicable shared/session guidance; operational logs remain UTC. Do not treat direct debug-script execution as a SAF filesystem sandbox.

The fresh SAF 2.0.0 5.1/7 fixture results cover the implemented script regressions and configuration values; the checklist remains available for repeat runs. Fresh-session Agent behavior, live remote initialization, actual Downloads redirection, and other-platform runtime remain separate acceptance. The structural audit checks present framework files and supported formats; it does not replace functional verification or prove Agent behavior.
