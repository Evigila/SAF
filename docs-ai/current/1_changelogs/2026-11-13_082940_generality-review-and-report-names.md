# Generality review and project-report naming

- Recorded: 2026-11-13 08:29:40, America/Sao_Paulo (UTC-03:00).
- Implementation reviewed: `47785cf9bc7f0ab268817f512891e3f728cbead9`.
- Scope: static generality/configuration review, the user's report-name correction, and clarification of shared documentation; no script fixes or functional test rerun.

The [review report](../saf-generality-review.md) traces every configuration field to script or Agent consumption. The actual source config resolves correctly in a read-only load, and the neutral seed does not copy source preferences. Four implementation findings remain open: transaction recovery can restore untouched paths, origin automatic backup omits existing config, singleton JSON arrays can lose root shape before validation, and protected missing paths can be created as ancestor directories. Prior 68-check 5.1 evidence does not cover all these cases. The report supplies causes, source locations, repair recommendations, and manual checks.

The user clarified that `1_` marks SAF template artifacts, not all AI-authored content. Renamed the ordinary project reports, preserving their report content:

| Previous name under `current/` | Current location |
| --- | --- |
| `1_framework-analysis.md` | [framework-analysis.md](../framework-analysis.md) |
| `1_saf-upgrade-proposal.md` | [saf-upgrade-proposal.md](../saf-upgrade-proposal.md) |
| `1_saf-modularity-proposal.md` | [saf-modularity-proposal.md](../saf-modularity-proposal.md) |

The archived modularity proposal now links to the renamed replacement. The append-only [initial analysis record](2026-11-12_104315_framework-analysis-and-audit.md) and [upgrade proposal record](2026-11-12_111755_saf-upgrade-proposal.md) retain their point-in-time names/links; this entry provides the current relocation targets rather than editing those records. The active modularity report's status also now identifies its completed implementation checkpoint and links the new review.

Shared rules reserve `1_` for the framework-defined template files/directories, limit release preparation to SAF source maintainers, and clarify that project-owned debug subprocesses are not filesystem-sandboxed. The first-use distribution URL is an overridable framework identity, not a consumer project policy. Agent verification/delivery/time-zone preferences remain instruction constraints, distinct from mechanical SAF write protection.

Prepared documentation patch 2.1.1 because the distributed shared rules changed; handler protocol 2 and config-support version 1 are retained. Existing script/config bytes, human README files, and earlier history are preserved. Static release/hash, link, format, and diff checks accompany delivery; any structural-audit completion is separate evidence about current SAF layout and formats, not resolution of the script findings. No commit, tag, push, installation, network retrieval, Computer Use, or new functional test result is part of this task.

Static release/hash and whitespace checks passed. Bounded structural inspection verified 23 payload targets, eight required directories, three skills, and 63 current/affected local file/heading references; the two renamed historical report bodies retain their original normalized hashes. Earlier append-only links are historical exceptions described above, not a claim that every history link was rewritten or validated. The shared state writer recorded structure-only version 2.1.1 completion at `2026-11-13T11:33:41Z`, preserving null source bootstrap/installation and the prior question state. Script behavior remains unchanged and the four findings remain open.
