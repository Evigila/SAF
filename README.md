# SAF

[English](README.md) | [简体中文](README_zh-CN.md)

> [!IMPORTANT]
> This project was developed with assistance from ChatGPT Codex.

SAF is a simple agent framework for existing Git repositories, allowing you to quickly inject a standardized agent framework and prompts.

## SAF's goals
1. **No installation / network fetch**: SAF lets you retrieve the necessary resources from the source repository through native command-line tools, **without** installing any additional client, CLI, or dependencies (other than Git).
2. **Root AGENTS.md**: SAF's core feature. Use the repository's root AGENTS.md for synchronization to avoid prompts falling out of sync across different environments and Harnesses. Git tracking is required to provide this synchronization.
3. **Quick injection**: SAF provides a standard set of experience-based framework prompts suitable for most projects. Enter the command to quickly retrieve the resources, then focus on developing your own project.
4. **Generality / configuration file**: SAF's design is focused on general use, while the configuration file lets you add personalized content! Of course, you can modify everything you want!

## Quick start

### Required:
- A Git-initialized repository
- Available Git
- Available command-line tools (PowerShell recommended)
- Basic programming knowledge (do not entirely trust SAF, they may be wrong)

### Not required:
- No specific Agent/Harness, but it must be able to read `AGENTS.md`
- No specific language or project dependencies

### What SAF cannot do:
- SAF will not install AI or any Agent/Harness for you, you need to use an Agent/Harness environment yourself
- SAF does not automatically discover, create, or install SKILLs, you maintain other skills as needed
- You are fully responsible for personalized content, SAF only provides a general recommended framework

Run following command at the target **Git repo**:

```bat
curl.exe -fL "https://raw.githubusercontent.com/Evigila/SAF/main/scripts/init.ps1" -o "$env:TEMP\saf-init.ps1"
if ($LASTEXITCODE -eq 0) {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\saf-init.ps1" -ProjectRoot "$PWD"
    if ($LASTEXITCODE -eq 0) { .\scripts\origin.bat -sync }
}
```

## What will your project receive?

| Path | Description |
| --- | --- |
| `AGENTS.md` `docs-ai/common/` | Entry point and shared standards |
| `.agents/saf/SAF.json` | SAF-control (do not modify) |
| `.agents/saf/SAF.config.json` | Project-specific configuration |
| `.agents/saf/SAF.lock.json` | SAF-control (do not modify) |
| `.agents/skills/` | Skills |
| `scripts/origin.bat` `scripts/local.bat` `scripts/` | Remote and local scripts |
| `debug.bat` | Centralized debugging bat for the project |
| `docs-ai/current/` | The current project's AI documentation, intended for AI, by default, **AI is only authorized to edit here** |
| `docs/` | The current project's documentation for humans, **AI has read-only access here**, and you should maintain these documents manually |
| `.agents/backup/` `.agents/saf_log/` `.agents/operation.lock` | Git-ignored backups, logs, and operation locks |

## Personalized

| Field | Description | Default |
| --- | --- | --- |
| `origin.repository` `origin.ref` | Upstream. After fork, you should specify your own upstream | - |
| `project.protectedPaths` | Relative file paths that AI must not write to or delete, directory paths end with `/` | `[]` |
| `project.verification.computerUse` | `deny` prohibits Computer Use. `inherit` uses the existing Harness permissions | `deny` |
| `project.ui.framework` | UI framework and design-specification preference | `Material Design 3` |
| `project.commit.style` | Commit-message style. `follow-history` follows the previous commit style | `follow-history` |
| `project.commit.initialStyle` | Initial commit-message style | `english-imperative` |


## origin commands

| Command | Behavior |
| --- | --- |
| `.\scripts\origin.bat -check` | Check the remote version |
| `.\scripts\origin.bat -update` | Update to a new version |
| `.\scripts\origin.bat -sync` | Check first, Update when available |
| `.\scripts\origin.bat -update -force` | Back up first, then overwrite local files with the remote version |

Double-clicking scripts/origin.bat runs `.\scripts\origin.bat -sync` by default.

Exit codes: `0` success, `1` error, `2` Check found an update, `3` local conflict, `4` bootstrap handlers need updating.

## local commands

| Command | Behavior |
| --- | --- |
| `.\scripts\local.bat -backup` | Back up the framework, configuration, state, AI documents, and skills to `.agents/backup/`, the project source is not included |
| `.\scripts\local.bat -clean-arquived` | Export `docs-ai/current/1_archived/` as a ZIP to the user's default Downloads folder, use `-Destination` to specify the output location |
| `.\scripts\local.bat -no-arquived` | Append archive ignore rules in .gitignore. You have to handle already tracked content |

## AI assistance

> [!IMPORTANT]
> This project was developed with assistance from ChatGPT Codex.

## License

[MIT License](LICENSE). The project was developed with assistance from AI Agent tools.
