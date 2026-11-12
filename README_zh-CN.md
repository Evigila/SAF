# SAF

[English](README.md) | 简体中文

> [!IMPORTANT]
> 该项目使用了ChatGPT Codex进行辅助开发

SAF (Simple Agent Framework) 是一个简易的注入型agent框架，适用于现有的Git仓库，快速注入标准化的agent结构和指令。

## SAF的目标
1. **无安装/网络获取**：SAF允许通过不安装额外客户端，CLI，依赖（除了Git以外）的方式，使用原生命令行即可从源仓库获取必要组件。
2. **根目录AGENTS.md**：这是SAF的灵魂，使用跟随根目录的AGENTS.md来同步，避免了不同环境不同Harness，指令无法同步的问题。这需要Git追踪提供同步能力。
3. **快速注入**：SAF提供一套标准的，适用于绝大多数项目的经验框架指令。输入命令并快速获取关键组件，然后即可专注于你的项目开发。
4. **通用性/配置文件**：SAF的核心指令以通用性为主，配置文件允许追加个性化的内容！当然，核心指令你也可以修改，克隆仓库后，由你来决定。

## 快速开始

### 必要的前提条件：
- 一个Git 初始化后的仓库
- 可用的 Git
- 可用的命令行工具（推荐Powershell）
- 基础编程知识（不要盲目相信SAF的指令，它可能会出错）

### 不是必要的：
- 没有指定的 Agent/Harness，但需要它能读取 `AGENTS.md`
- 没有指定的项目语言或者项目依赖

### SAF不能做到的事情：
- SAF不会帮你安装AI或者任何Agent/Harness，但它需要你自己使用某种Agent/Harness环境
- SAF不会自动发现，创建或安装SKILL，其他技能由你按需维护
- 个性化内容需要全权由你负责，SAF只提供一套通用的推荐标准框架

在目标 **Git 根目录**执行：

```powershell
irm https://raw.githubusercontent.com/Evigila/SAF/main/scripts/init.ps1 | iex
.\origin.bat -sync
```

或者使用curl（当PowerShell出现问题时）：

```bat
curl.exe -fL "https://raw.githubusercontent.com/Evigila/SAF/main/scripts/init.ps1" -o "%TEMP%\saf-init.ps1" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\saf-init.ps1" -ProjectRoot "%CD%" && call origin.bat -sync
```

## 你的项目会获得什么？

| 路径 | 描述 |
| --- | --- |
| `AGENTS.md` `docs-ai/common/` | 入口和通用标准 |
| `SAF.json` | SAF控制（请勿修改） |
| `SAF.config.json` | 项目个性化配置 |
| `SAF.lock.json` | SAF控制（请勿修改） |
| `.agents/skills/` | 技能 |
| `origin.bat` `local.bat` `scripts/` | 远程和本地脚本 |
| `debug.bat` | 适用于项目的集中调试入口 |
| `docs-ai/current/` | 当前项目的ai文档入口，适用于ai，默认情况下，ai仅被授权在此处编辑 |
| `docs/` | 当前项目的文档入口，面向人类，ai在此处只读，你应该手动维护这里的文档 |
| `.agents/backup/` `.agents/saf_log/` `.agents/operation.lock` | 它们是Git 忽略的备份，日志和运行锁 |

## 个性化配置（由你来决定）

| 字段 | 描述 | 默认值 |
| --- | --- | --- |
| `origin.repository` `origin.ref` | 更新源。Fork 后你应该指定自己的源 | - |
| `project.protectedPaths` | 禁止ai写入或删除的相对文件路径，目录以 `/` 结尾 | `[]` |
| `project.verification.computerUse` | `deny` 禁止使用Computer Use。`inherit`使用现有Harness权限 | `deny` |
| `project.ui.framework` | UI 框架以及设计规范偏好 | `Material Design 3` |
| `project.commit.style` | 提交消息风格。`follow-history` 跟随此前的提交风格 | `follow-history` |
| `project.commit.initialStyle` | 提交消息初始风格 | `english-imperative` |


## origin 命令

| 命令 | 行为 |
| --- | --- |
| `.\origin.bat -check` | 检查远端的版本 |
| `.\origin.bat -update` | 更新到新版本 |
| `.\origin.bat -sync` | 先 Check，可用时 Update |
| `.\origin.bat -update -force` | 先备份，再用远端版本覆盖本地文件 |

双击origin.bat时默认调用`.\origin.bat -sync`

退出码：`0` 成功，`1` 错误，`2` Check 发现更新，`3` 本地冲突，`4` 需要更新初始化处理器。

## local 命令

| 命令 | 行为 |
| --- | --- |
| `.\local.bat -backup` | 将框架，配置，状态，AI 文档和技能备份到 `.agents/backup/`，不包含完整项目源码 |
| `.\local.bat -clean-arquived` | 将 `docs-ai/current/1_archived/` 导出为ZIP到默认用户下载目录，可用 `-Destination` 指定输出位置 |
| `.\local.bat -no-arquived` | 追加归档项忽略规则。已跟踪内容需要你自行处理 |

## AI辅助

> [!IMPORTANT]
> 该项目使用了ChatGPT Codex进行辅助开发

## 许可证

[MIT License](LICENSE)。项目使用 AI Agent 工具辅助开发。
