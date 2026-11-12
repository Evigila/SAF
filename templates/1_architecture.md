# Project architecture and key relationships

**Status:** Project facts have not been inspected. Populate this document when a project architecture task is requested or when actual structural changes require an update. Completing project architecture facts is a separate task, not a prerequisite for a SAF framework structure audit.

## Scope and maintenance

Describe key files, directories, projects, responsibilities, and dependency direction. Use relationship tables and concise explanations; an exhaustive file tree is not required. Focus on the maintained modules and boundaries needed to understand the project.

Maintain this document alongside real changes to key modules, entry points, project references, responsibilities, or runtime boundaries. Record facts from affected implementation and configuration when that work is in scope; do not inspect all project source or dependency facts merely because the periodic SAF structure audit is due.

Generated outputs, caches, temporary files, Git internals, and local SAF recovery/log data do not need individual entries. Describe documentation areas by their ownership when useful rather than listing their contents.

## Key files and modules

Describe important root files and directories, significant modules, and their relationships. For SAF integration, identify `AGENTS.md`, release-owned `SAF.json`, project-owned `SAF.config.json`, observed `SAF.lock.json`, the `origin.bat`/`local.bat` handlers and their scripts, and project-owned `debug.bat` when relevant. `Resolve-SafConfig -Root` supplies validated defaults/restrictions to handlers and Agent workflows; do not copy central project preferences into this project's facts. Skills remain `.agents/skills/`, distinct from runtime `.agents/backup/`, `.agents/saf_log/`, and `.agents/operation.lock`. The trusted `scripts/init.ps1` is a source-only bootstrap, not a required consumer file. A menu alone does not establish implemented project operations.

| Key path or module | Responsibility | Depends on / used by | Evidence or unresolved fact |
| --- | --- | --- | --- |

## Solution and project boundaries

When project architecture work is in scope, identify actual solutions and significant executable, library, test, example, or infrastructure projects. Describe references and dependency direction. A project boundary alone does not establish an independently deployed service. State when no solution/project files exist.

| Solution or project | Kind and responsibility | References / dependency direction | Runtime boundary |
| --- | --- | --- | --- |

## Runtime and resource boundaries

For the affected architecture scope, describe processes, entry points, deployment units, persistence, and external resources established by implementation or configuration. Explain communication and ownership without duplicating the dependency inventory. Mark unverified facts as unknown rather than expanding a SAF structure audit into a business architecture investigation.

| Application or resource | Runtime/deployment boundary | Communication or persistence | Evidence |
| --- | --- | --- | --- |

## Active project constraints and exceptions

Record applicable project-specific constraints and authorized exceptions, with their scope and evidence. Keep completed approval narratives and superseded decisions in the history directories.

## Verification and unresolved facts

Record the project architecture inspection scope, evidence, and unresolved facts. Distinguish source inspection from executed verification. A SAF framework structure audit verifies framework structure and its required documents; it does not establish the accuracy or completeness of project source, business architecture, or dependency facts. This template may remain unpopulated until that separate project work is authorized.
