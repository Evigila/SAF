# SAF rule modularity and project configuration proposal

**Status: Superseded, not implemented.** The user clarified that periodic auditing covers SAF framework structure only, English and root-script restrictions are deliberate standards, architecture documents describe key relationships, and `AGENTS.md` already is the project-rule entry point. Recommendations below that contradict these boundaries are withdrawn. The affected scope is the earlier modularity/configuration analysis; see the [corrected assessment](../saf-modularity-proposal.md) for its replacement. Historical baseline references in this archived proposal are retained as evidence, not current policy.

## Status and baseline

Status: Analysis and proposed design, not implemented. Inspected on 2026-11-12 against commit `28ede113f679e9f0d2e4f43895d875d696231196` (`feat: upgrade SAF to 2.0.0`). The user requested that checkpoint before this analysis; it contains the SAF upgrade and verified Windows PowerShell 5.1 corrections. The commit was created locally and was not pushed. The worktree was clean immediately after it.

This proposal does not change effective rules, introduce an executable configuration format, or authorize another architecture implementation. README ownership remains with the user. No README was edited during this task. The current audit gate skips a new full audit because release/audit versions match and the completed audit is current.

## Assessment

The current framework can separate rules and support project customization without an external dependency or plugin runtime. Its router, shared policies, three skills, project facts, managed files, and seed ownership already provide useful foundations.

The remaining coupling is mostly between framework invariants, operational contracts, and governance preferences inside `rules.md`. The code and UI files have already removed organization and framework requirements; splitting their short generic guidance into many fragments would add reading overhead without clear benefit.

The key distinction is ownership and interpretation: configuration supplies finite values, project prose supplies contextual rules, and shared modules supply reusable guidance. Those categories require different update and conflict behavior.

## Current problems and evidence

| Finding | Practical effect | Evidence at the baseline |
| --- | --- | --- |
| No separate project configuration or standard project-rule entry | Personalization tends to modify managed common files or remain in conversation/history; the former conflicts with updates and the latter may not be read reliably. | `AGENTS.md:25-40`; `scripts/origin.ps1:22-24`; manifest ownership |
| Mandatory calendar-month full audit | A small task can expand into full repository governance regardless of project size or desired cadence. | `docs-ai/common/rules.md:25-36` |
| Full maintained-file tree and all dependencies must be represented in the prescribed inventories | Useful for small projects, expensive for large repositories when equivalent maintained manifests and resolution evidence already exist elsewhere. | `docs-ai/common/rules.md:63-73`; consumer templates |
| Audit repairs must be English | Language preference remains embedded in a procedural skill. | `.agents/skills/audit-project-docs/SKILL.md:12` |
| Root script allowlist and unified debug requirement govern consumer operations | Existing Makefile, package scripts, shell entry points, or root build scripts may be unnecessarily constrained. | `docs-ai/common/rules.md:163-169` |
| Human ownership is centered on `docs/` | Additional protected files such as the user-maintained README pair cannot be represented persistently in a structured project setting. | `docs-ai/common/rules.md:15-19`; this session's explicit README restriction |
| Test and delivery habits are shared standards | Computer Use prohibition and asking about commits are appropriate here, but other consumers may select different authorized workflows. | `docs-ai/common/rules.md:171-183`; `docs-ai/common/UIUX.md:19` |
| Project exceptions coexist with facts/history under current | The generic exception mechanism exists, but no canonical active project-policy location is routed or protected from memory consolidation. | `docs-ai/common/rules.md:9,59,151-155`; compression skill |
| Some paths are fixed in several executables | Renaming a documentation or archive root through configuration alone would produce inconsistent ownership, backups, ignore rules, or deletion scope. | `scripts/saf-core.ps1:112-118,239-277,326-333`; `scripts/local.ps1:16,63-81`; publisher |

The last finding is an implementation boundary, not evidence that every fixed path is a defect. Stable names such as `AGENTS.md`, `SAF.json`, and skill discovery paths help interoperability. The generic objective does not require arbitrary remapping of all protocol locations.

## Proposed layers

| Layer | Contents | Owner and loading |
| --- | --- | --- |
| Core boundaries | Effective instruction hierarchy/task authorization, declared ownership, truthful evidence, conflict reporting, protected state and validated filesystem operations | Framework-managed; always applicable within SAF, subject to the host's actual instruction hierarchy |
| Reusable rule modules | Code/UI integration, documentation governance, audit, history, and SAF operation guidance | Framework-managed; load only task-relevant modules |
| Structured project configuration | Explicit language, audit schedule, inventory representation, additional protected paths, and optional source defaults | Consumer-owned; parsed and validated, never interpreted as code |
| Project rules | Technology/naming conventions, approved design system, testing restrictions, build/publication entry points, and scoped exceptions | Consumer-owned prose; separate from factual inventories and history |
| Facts and state | Verified architecture/dependencies/history and actual installation/audit results | Existing current documents and `SAF.lock.json`; not desired settings or new grants of authority |

Core truth requirements remain invariant: a summary cannot claim an unperformed complete audit, a setting cannot mark tests passed, and a project setting cannot expand an operation beyond authorization. Ownership policy can add protected paths, but it does not silently authorize editing existing human content. Explicit task instructions continue to take precedence under the effective runtime hierarchy.

## Minimal file organization

```text
AGENTS.md                         framework-managed reading router
SAF.json                          release manifest
SAF.lock.json                     actual installed/audited state
SAF.config.json                   optional consumer-owned settings
docs-ai/
  common/
    rules.md                      compact core boundaries and references
    codedesign.md                 existing code module
    UIUX.md                       existing UI module
    documentation.md              audit, inventories, history, compression
    saf-operations.md             bootstrap, origin/local, state and recovery
  project/
    rules.md                      optional consumer-owned project policy
  current/                        verified facts, reports and history
.agents/skills/                   existing scoped workflows
```

Only two new shared Markdown modules are initially proposed. Keep the existing three common entry files so existing required targets and reading references remain useful. Retain compatibility anchor headings as links to their new owning module where needed. Register each new managed module in the existing manifest with its hash; the current common-subtree allowlist already supports this.

The dedicated `docs-ai/project/rules.md` is recommended to separate long-lived project policy from memory targeted by `compress-saf`. Keeping a policy file directly under current would involve fewer new paths, but would require explicit exclusions throughout compression/audit routing. The project directory should be optional and created only when needed; this proposal does not require a file per preference.

Skills remain procedural workflows. They read the relevant effective settings and modules instead of restating language, cadence, or ownership rules. No universal "run all skills" package, model adapter, remote module loader, or executable plugin system is needed.

## Configuration boundary

Do not mix project choices into the release manifest or installation lock:

| File | Meaning | Update behavior |
| --- | --- | --- |
| `SAF.json` | What the publisher releases and owns | Managed, versioned payload |
| `SAF.config.json` | What this project explicitly selects | Optional project-owned file; seed only when absent, never overwritten by update/Force/init repair |
| `SAF.lock.json` | What was actually installed and audited | Coordinated state writers preserve unrelated sections |
| `docs-ai/project/rules.md` | Contextual project instructions | Project-owned; no automatic replacement or memory archiving |

One additional root configuration file provides a clear ownership boundary. Reusing a release-owned or generated state file merely to reduce file count would cause competing writers and update conflicts.

An illustrative first schema is:

```json
{
  "schemaVersion": 1,
  "documentation": {
    "language": "zh-CN",
    "inventoryMode": "full-inline"
  },
  "audit": {
    "mode": "periodic",
    "intervalMonths": 1
  },
  "ownership": {
    "additionalHumanPaths": [
      "README.md",
      "README_zh-CN.md"
    ]
  }
}
```

This JSON is a proposed interface, not a format recognized by SAF 2.0.0. The default seed should contain only `schemaVersion`, rather than copying every default. Missing properties inherit; explicit invalid/null values do not silently inherit. Objects merge only at declared fields, and arrays replace the corresponding configurable list. Core-protected paths remain additive to project protections.

Recommended initial choices:

- Documentation language: explicit project language or follow existing project documents. Replace the audit skill's hard-coded English instruction.
- Audit mode: retain current periodic behavior when no configuration exists; later support explicit-only or task-relevant evidence triggers. No mode fabricates audit completion, and facts required for a task must still be verified.
- Inventory mode: current complete inline inventories, or an overview backed by a maintained complete inventory/resolution evidence reference. The second form changes representation, not the truth of completeness. Record the actual audited scope/evidence; do not label a partial overview as a complete inventory.
- Additional human paths: bounded repository-relative file/directory references, including the README pair here. Do not use arbitrary expressions or allow a setting to reduce session/user protections.
- Source defaults, when requested: optional `origin.repository` and `origin.ref`. Do not put them in the default seed, which could reset an existing consumer's custom repository or commit pin.

Testing restrictions, namespace/design-system choices, and native project commands are better expressed in project prose first. Introduce typed settings for them only when a concrete consumer or runtime actually uses the field. Do not advertise ineffective configuration keys.

The first release should keep SAF's archive, backup, log, state, and managed-file roots fixed. A user-selected archive root accidentally pointing to business source must not become deletion authority. Configurable root paths require a coordinated protocol/migration design across validators, seeds, backups, ignore rules, skills, and fixtures.

## Resolution and enforcement

Parameter precedence and instruction authority are separate:

- Runtime values: an explicitly supported CLI option, then an explicitly set project value, then prior lock provenance as a source-only compatibility fallback, then framework defaults. An absent `origin` section must preserve an existing installation pin. Use bound-parameter presence rather than truthiness to distinguish missing from invalid empty arguments.
- Policy defaults: the effective user/task instructions and core boundaries constrain interpretation. Explicit project policies can override declared configurable defaults; ambiguous or contradictory same-level requirements are reported with their sources. Reading a file last does not grant it unrestricted precedence.

A common `Resolve-SafConfig` helper should return validated effective values and their provenance. Native readers and skills must share its merge/validation semantics. Machine-consumed fields require actual wiring in init/origin/local; Agent-consumed preferences require the router and relevant skills to read them. Do not assume a PowerShell process understands Markdown, or that a host automatically discovers arbitrary module files.

The resolver should reject unsupported schemas, unknown keys, invalid types/enums, credential-bearing source URLs, unsafe references, and missing declared project-policy files. It must not evaluate strings, execute commands, load remote policy URLs, or enlarge managed ownership from config. Use built-in PowerShell 5.1 JSON/type checks; no new package is necessary.

Parse one configuration snapshot per operation. Before writes, check that its source files have not changed since planning. Expose effective values and sources through a small diagnostic surface, rather than persist a second authoritative config cache. Preserve Check's existing log-only write contract. Built-in defaults should have one resolver owner; modules reference those settings instead of each independently defining defaults. Bootstrap must remain usable before full common-document installation, so resolution cannot depend on a file that init has not deployed.

## Audit and update integration

The present audit gate compares framework version and time. A project can change audit scope or policy without changing framework version. A future completed audit should therefore retain an effective audit-policy fingerprint and the scope/evidence it actually verified, using the existing coordinated audit-section writer. A changed policy invalidates reuse when appropriate; it never updates the completion timestamp by itself. Ordinary source/ref overrides need not be treated as a completed project-policy audit.

Keep config and project policies outside managed hashes. Adding their specific seed paths requires changes to the current seed validator/publisher, init behavior, and backup inventory. Project-added policy/config must survive Update, Force, and handler repair. An explicitly protected common file should cause a reported policy/ownership conflict, not silently become overwritable.

Existing consumers with no config retain current behavior. Before moving local common customizations into project policy, classify them against the imported baseline: genuine project preferences can move, generic corrections remain framework proposals, and obsolete/conflicting edits require review. Do not auto-convert every textual difference into valid instructions.

New modules can initially ship with the complete payload and load only as relevant. Disabling automatic module reading must not delete documents, skills, archives, or consumer facts. Independent module release channels and dependency resolution are unnecessary at this scale. Keep one SAF release/manifest.

Document-only extraction can preserve existing runtime contracts. Config-driven write/ownership behavior must declare a handler capability/protocol that older code actually checks; an ignored unknown manifest field is insufficient. Preserve the existing init recovery route and verify old-handler behavior before promising backward compatibility. The final release number depends on that implementation's compatibility assessment.

## Suggested implementation sequence

1. Classify current policies and extract documentation/SAF-operation guidance, keeping existing entry files/anchors and behavior unchanged.
2. Introduce the optional project-rule path with clear consumer ownership, reading order, and compression exclusion.
3. Add a minimal optional config, one strict resolver, and only the fields with real consumers. Preserve all old defaults when absent.
4. Connect audit language/cadence and additional protected paths; update skill/manifest/backup/seed handling as a coherent change. Keep general project command conventions in project policy rather than universally requiring `debug.bat`.
5. Extend audit provenance for effective policy/scope and exercise migration and conflict behavior. Decide whether optional module controls are useful after the basic separation works.

Acceptance should cover config absence, sparse inheritance, source-pin preservation, invalid schema/types/keys, explicit CLI versus config precedence, protection of README/project rules through Force/init, config changes during an operation, policy-change audit invalidation, module-relevant reading, compression exclusion, and unchanged behavior under Windows PowerShell 5.1. These are proposed checks; none was executed for an unimplemented design.

## Outcome of this task

The existing SAF 2.0.0 checkpoint was committed as requested and its payload hashes revalidated. This task adds only this analysis document after that commit. No active framework rule, executable, release manifest, state schema, or README was changed for modularity. No second commit or push was made. The earlier 34-check PowerShell 5.1 result remains prior evidence, not a test of this proposal.
