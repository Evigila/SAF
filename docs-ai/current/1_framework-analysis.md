# Framework analysis

**Historical analysis:** This document describes release 1.2.1 before the SAF 2.0.0 upgrade. Its implementation/policy descriptions are superseded by the [SAF 2.0.0 implementation record](1_changelogs/2026-11-12_113446_saf-2-upgrade.md) and current architecture/dependency inventories. The original analysis below is retained as historical evidence.

## Scope and status

Inspected on 2026-11-12, America/Sao_Paulo (UTC-03:00), against source revision `c89cf42b28b6ea540c4b109f614e016971d7eb32`, framework release `1.2.1`. This is an initial source and policy analysis, including the required monthly documentation audit. It does not establish functional test results. No framework payload, shared policy, release version, or dependency declaration was changed.

The framework is a repository instruction and documentation-governance system with a versioned installer. It does not implement model execution, agent scheduling, tool registration, or agent-to-agent communication. Its delegation policy asks the host agent runtime to use bounded subagents where available; the runtime supplies that capability.

## Structure and normal workflow

| Layer | Responsibility | Evidence |
| --- | --- | --- |
| Entry router | Select task-relevant reading and preserve instruction ownership | `AGENTS.md` |
| Shared policies | Define code conventions, execution boundaries, documentation ownership, audit, and UI integration | `docs-ai/common/` |
| Skills | Execute audit and explicitly requested synchronization workflows | `.agents/skills/` |
| Project facts | Describe the actual repository, dependencies, decisions, and history | `docs-ai/current/` |
| Release manifest | Define versioned source/target paths, modes, and normalized hashes | `AGENTS.framework.json` |
| Consumer installation lock | Record imported payload commit, manifest digest, managed baselines, and optional launcher provenance | Generated `AGENTS.lock.json` |
| Audit state | Record the framework version actually audited and audit completion time | `AGENTS.ensure.json` |

The normal consumer workflow is bootstrap, install verified managed files and missing seeds, audit and populate local facts, perform ordinary tasks through the router, and explicitly synchronize when requested. A changed framework version makes a new audit due; synchronization itself does not complete an audit.

The manifest has 18 entries: 10 managed and 8 seed entries. The installed manifest and generated lock are additional installation files. Central architecture/dependency facts, README files, tests, publisher, and CI are not copied as consumer facts. Templates deliberately remain unverified until a consumer audit completes.

## Strengths established by source inspection

- The router, policies, procedural skills, project facts, and history have distinct owners. Mandatory rules do not depend on implicit skill matching.
- Human documentation under `docs/` is protected, and seed mode preserves consumer facts and nonempty operation-menu customizations, including during forced synchronization.
- Managed-file conflicts use imported hashes rather than Git cleanliness, so committed local customizations remain detectable.
- Payloads are read from one resolved Git commit and checked after BOM/newline normalization. Path validation, regular-blob checks, and destination reparse-point checks constrain filesystem operations.
- Synchronization plans changes before writing, backs up conflicting files when forced, replaces individual files atomically, and writes the lock last. Caught write failures attempt snapshot restoration.
- Launcher provenance is separate from payload provenance. Historical payload rollback can retain a current launcher capable of upgrading again.
- Tests use temporary Git fixtures without third-party test packages. CI declares Windows PowerShell 5.1, Windows PowerShell 7, and Linux PowerShell 7 jobs.

These are implementation properties, not a claim that all associated runtime scenarios passed during this analysis.

## Findings and design tradeoffs

| Priority | Finding | Cause and practical effect | Evidence |
| --- | --- | --- | --- |
| High | Generic repository positioning includes mandatory ecosystem-specific policies | `ArkheideSystem.`/`Arkheide.` namespace requirements and Flourish UI authority are centrally managed defaults. In unrelated projects they can trigger irrelevant migration discussions or block UI work when Flourish source/capabilities are absent. | `README_zh-CN.md:5`; `docs-ai/common/codedesign.md:32`; `docs-ai/common/UIUX.md:5,18,22,41-46` |
| Medium | Installation is light, but governance is substantial | Monthly full audits require a complete maintained-file tree and every resolved transitive dependency. Large or frequently changing repositories pay recurring documentation and context costs. Task-specific routing reduces ordinary-task reading but does not eliminate audit cost. | `docs-ai/common/rules.md:37,74-90` |
| Medium | Payload pinning does not freeze the controller | Every BAT invocation clones the fixed central `main` before running the selected payload workflow, including when `-SourcePath` is local. This helps migration but adds central availability and compatibility dependencies; a historical payload is not a completely frozen execution environment. | `fetch-agents.bat:8,56,64`; `scripts/fetch-agents.ps1:204-218,294-297` |
| Medium | Portability is uneven | The PowerShell installer is portable by design, while the normal launcher and fixed operation menu target Windows and include NuGet-specific workflow. Linux CI does not validate BAT behavior; macOS has no CI job. | `debug-handler.bat`; `.github/workflows/verify.yml:20-30`; `README.md:9-13` |
| Medium | Filesystem recovery has explicit limits | Individual atomic replacements and best-effort rollback do not provide a whole-directory transaction, concurrent-run exclusion, or crash recovery. No dedicated destination-link or injected mid-write-failure fixture was identified in the reviewed test suite. This is a coverage/guarantee limit, not an observed corruption bug. | `scripts/fetch-agents.ps1:96-108,131-139,355-396`; `tests/test-sync.ps1` |
| Informational | Hash validation is not independent publisher authentication | Manifest and payload come from the same selected source. SHA-256 checks establish internal consistency; trust still rests on the selected repository and central controller source. | `fetch-agents.bat:56-61`; `scripts/fetch-agents.ps1:236-238,276-288` |

The router, three common policy files, and two skill manifests contain approximately 41 KB in this checkout; `rules.md` is 191 lines. The installer is 406 lines, and the integration suite is 1126 lines. There are no extra package-manager/runtime dependencies beyond the documented platform tools. "Lightweight" accurately describes distribution and runtime requirements; policy and compatibility maintenance carry most of the complexity.

No confirmed synchronization logic defect was established by this source review. The policy portability gap is confirmed by the effective rules, while transaction, availability, and test-coverage items remain design constraints or risks requiring functional evidence.

## Proposed next steps

1. Decide whether the intended audience is the Arkheide/Flourish ecosystem or general Git repositories. If the former, document that scope clearly; if the latter, consider optional ecosystem policies while retaining a small mandatory core.
2. Review whether monthly full inventories are appropriate for every consumer size. Any incremental-audit proposal must retain explicit completeness and invalidation rules; none is implemented here.
3. Preserve the managed/seed split, local-fact isolation, separate audit/installation state, and current launcher recovery behavior when simplifying the framework.
4. Before expanding synchronization features, evaluate focused regression coverage for destination links and write-failure rollback. Define same-target concurrency behavior before claiming support.

These are proposals only. This analysis does not authorize or implement a policy migration, installer redesign, or new dependency.

## Verification performed

- All 18 required source-repository paths were present. A consumer lock is intentionally not required in the central source repository.
- The architecture tree matched all 22 maintained files outside its documented exclusions.
- All 18 manifest entry hashes matched local source after the required text normalization.
- All 26 local file links in the router, README files, shared policies, two skills, and architecture/dependency inventories had existing destinations. Heading anchors were not separately validated.
- Both skill packages had scoped front matter and UI metadata; both consumer fact templates explicitly retained their incomplete status, and the audit seed retained null completion fields.
- The installer, publisher, and test script parsed without errors under Windows PowerShell 5.1 and PowerShell 7. Parsing does not execute their behavior.
- Local tool/runtime observations were refreshed in [the dependency inventory](1_dependency.md).

No integration suite, BAT interaction, network synchronization, live bootstrap, CI job, or Computer Use test was run. Existing CI configuration and test assertions were inspected as coverage evidence only.

## Recommended manual verification

Use a disposable Git repository rather than the central framework source as the installation target.

| Scenario | Expected observation |
| --- | --- |
| Fresh installation and first audit | Managed files arrive; fact templates are unverified; audit state remains null until the consumer audit succeeds. |
| Check before installation and after installation | `fetch-agents.bat -NonInteractive -Check` returns 2 when installation is needed and 0 when current, without changing target files. A managed customization produces 3. |
| Local customization and Force | Ordinary update refuses conflicting committed or uncommitted managed content; authorized Force preserves exact original bytes in backups. |
| Seed preservation | Existing `current/`, audit state, human documents, custom skills, and nonempty debug menu survive update and Force; a legacy zero-byte debug menu receives the seed. |
| Historical pin, rollback, and upgrade | Payload provenance and launcher provenance remain distinct; rollback retains an entry point that can upgrade again. |
| Menus and automation | No operation begins before input; empty Enter chooses the displayed default; invalid input repeats; EOF cancels; operation codes survive the final wait. First-argument `-NonInteractive` skips both waits. |
| Central source unavailable | BAT fails without target writes or fallback to the installed project script, including with a local payload source. |
| Destination link and write failure | Links are refused without touching external paths. Injected mid-write failures restore prior content and lock where recovery is possible. |
| Unrelated project ecosystem | In a project without Arkheide/Flourish, observe whether the mandatory policies create unwanted work or prevent intended implementation. |
| Month/version audit boundary | A calendar-month deadline or changed framework version triggers a full audit; an ordinary successful task does not refresh completion time. |

Maintainers can also run `scripts/publish-framework.ps1 -Check` and `tests/test-sync.ps1` under each supported PowerShell edition. These commands are recommended checks, not results from this task. Avoid simultaneous synchronizations against one target until an explicit concurrency guarantee exists.
