# SAF 2.0.0

[English](https://github.com/Evigila/AGENTS.md/blob/main/README.md) | [简体中文](https://github.com/Evigila/AGENTS.md/blob/main/README_zh-CN.md)

SAF 是面向现有 Git 仓库的轻量指令与项目记忆框架，分发规则、Agent 技能和仓库内 Windows 处理器。不安装应用、全局 CLI、服务、包管理器或运行时，不强制组织命名空间或 UI 组件库。

## 前提和初始化

使用已有 Git 仓库、PATH 中现有 Git，以及 Windows PowerShell 5.1 或已经安装的 PowerShell 7。BAT 入口依赖 Windows。目标必须是 Git 根目录，不能是任意子目录。

本版本的 `init.ps1` 发布到配置仓库的 `main` 后，在目标 Git 根目录执行：

```powershell
irm https://raw.githubusercontent.com/Evigila/AGENTS.md/main/init.ps1 | iex
.\origin.bat -sync
```

当前源仓库仍为 `Evigila/AGENTS.md`，不假设未来的 `Evigila/SAF` 地址已经存在。上面的远程命令依赖新初始化脚本完成发布；发布前可从可信的源码检出目录执行：

```powershell
& C:\path\to\source\init.ps1 -ProjectRoot C:\path\to\target
```

Init 默认捕获调用者当前目录，从同一个源提交验证并部署 `origin.bat`、`local.bat` 和三个 PowerShell 辅助文件，替换前备份旧处理器，向现有 .gitignore 追加本地备份、日志及操作锁忽略规则，保留项目事实及已有安装、审计证据。之后运行 origin 同步完整载荷。处理器损坏或不兼容时重新运行可信 init，无须删除锁文件。

Init 支持 `-ProjectRoot`、`-Repository` 和 `-Ref`。远程脚本需要显式参数时，通过脚本块调用，不把参数追加到 `iex`：

```powershell
$initUrl = 'https://raw.githubusercontent.com/Evigila/AGENTS.md/main/init.ps1'
& ([scriptblock]::Create((irm $initUrl))) -Repository 'https://github.com/Evigila/AGENTS.md.git' -Ref main
```

执行前应审阅并信任初始化来源。已发布的固定提交 URL 有助于复现；后续清单哈希不能独立认证已经执行的初始化代码。

## 文件职责

| 路径 | 职责 |
| --- | --- |
| `AGENTS.md` | 任务阅读路由 |
| `docs-ai/common/` | 当前有效的共享标准 |
| `.agents/skills/` | `sync-saf`、`audit-project-docs`、`compress-saf`；允许并存用户技能 |
| `SAF.json` | 发布版本、兼容合同和载荷哈希 |
| `SAF.lock.json` | 分离的初始化来源、安装基线和审计状态 |
| `origin.bat`、`scripts/origin.ps1` | 远程版本检查与同步 |
| `local.bat`、`scripts/local.ps1` | 离线备份、归档导出清理和忽略配置 |
| `scripts/saf-core.ps1` | 路径、哈希、状态合并和操作锁等公共实现 |
| `debug.bat` | 仅初始化一次的项目自有操作入口 |
| `docs-ai/current/` | 项目事实、变更记录、问题证据和归档 |
| `docs/` | 人工文档；AI 修改需明确授权 |
| `.agent/backup/` | Git 忽略的本地恢复快照 |
| `.agent/saf_log/` | Git 忽略的追加式命令日志 |

SAF 状态和受管框架文件应纳入 Git。源仓库的 README、init、发布器、测试、CI 和 templates 目录不作为消费者载荷复制。新项目事实模板在项目自身审计完成前仍为未验证。

## 远程命令

| 命令 | 行为 |
| --- | --- |
| `.\origin.bat -check` | 检查选定发布、兼容性及本地冲突 |
| `.\origin.bat -update` | 应用选定发布，已是当前状态则不更新 |
| `.\origin.bat -sync` | 先检查，可用时更新，始终使用同一个已解析提交 |
| `.\origin.bat -update -force` | 备份并替换有冲突的受管文件 |
| `.\origin.bat -Repository "Git URL" -Ref "分支/标签/提交" -sync` | 显式指定兼容来源和引用 |

双击或无参数默认直接 sync，结束后等待以保留结果窗口。显式动作参数不再要求开始确认或结束等待。拒绝冲突动作和单独的 Force；Force 仅修饰 Update，不能覆盖项目自有模板、绕过路径和载荷校验，也不改目标 Git 远端、索引、分支或提交。

Check 不改框架文件、`SAF.json` 或 `SAF.lock.json`；唯一的项目写入例外是 `.agent/saf_log/` 命令日志。日常 origin 使用已部署的本地实现读取验证后的远程发布数据，不另行执行独立变化的远程控制器。

退出码：`0` 成功/当前；`1` 错误；`2` Check 发现更新；`3` 本地冲突；`4` 需要重新初始化处理器。仅检查版本不授权执行更新。

## 本地维护

无参数展示菜单，第一项 Backup 为默认；空回车执行备份，非法输入重试，输入结束取消，操作后等待展示结果。显式动作不等待输入。

- `.\local.bat -backup`：在 `.agent/backup/<UTC时间>-<唯一ID>/` 保存 SAF 恢复快照，含框架、状态、AI 文档及技能的原始内容、清单和哈希。排除旧备份、日志、Git 内部、缓存及无关源码；不是全仓库备份。
- `.\local.bat -clean-arquived`：仅将 `docs-ai/current/1_archived/` 导出至当前用户真实 Windows 下载目录中的唯一 ZIP，核对包含隐藏文件的全部条目及内容，再删除未变化的已导出文件。保留目录和标记，报告部分清理；导出或校验失败则不删除源内容。
- `.\local.bat -no-arquived`：追加归档子项忽略规则，保留 `.gitkeep` 和已有忽略内容；不改索引、不提交、不推送，也不删除远端文件。

保留用户指定的 `arquived` 命令拼写。Git 已跟踪的归档不会因 ignore 停止跟踪；导出清理会为已跟踪文件产生本地删除差异，用户日后提交可能删除远端分支中的对应文件。仅配置忽略不会执行这些删除。

下载目录通过当前用户 Windows User Shell Folders 中的 Downloads GUID 读取，支持目录重定向。日志位于 `.agent/saf_log/<UTC日期>.jsonl`，记录动作、结果及恢复引用，不记录密钥或完整文件内容。操作日志不能替代项目历史。

## Agent 技能与项目操作

框架同步使用 `$sync-saf`；文档审计使用 `$audit-project-docs`；AI 项目记忆语义精简使用 `$compress-saf`。没有原生技能发现机制时，Agent 可直接读取对应包的 `SKILL.md`。审计和压缩仅作为技能，不提供 `local.bat -audit`、`-compress` 或模型引擎适配器。

审计通过公共状态方法仅更新 audit 区块，初始化和更新不会标记审计完成。压缩先保留恢复快照，保持完整清单、有效约束和未完成工作，将过时的活动报告归档，不重写变更记录或问题证据，也不执行 ZIP 清理或刷新审计时间。

项目自有 debug 种子提供 Debug、Clear database、Publish tag、Publish package 菜单。这些是未配置的可选示例，不强制包生态；按授权在 `scripts/` 配置或调整项目操作。非空自定义入口在更新和 Force 下保留。显式选择，例如 `.\debug.bat 1`，无交互等待。

## 迁移与验证

旧安装及审计元数据转换为 `SAF.lock.json` 时保留原证据；对同时存在且冲突的状态不猜测覆盖。已有 debug 定制保全迁移或报告冲突。SAF 2 不承诺直接回退到历史 pre-SAF 安装器；处理器恢复通过可信 init 完成。

功能验证是独立工作，文档或静态检查不能证明运行行为。建议手动检查首次初始化/恢复、检查/更新/同步/冲突/Force、更新不刷新审计、离线备份、下载目录重定向与导出失败、已跟踪归档的忽略行为，以及审计/压缩的状态和内容保留。不使用 Computer Use 测试项目。

## 许可证

[MIT License](https://github.com/Evigila/AGENTS.md/blob/main/LICENSE)。项目使用 AI Agent 工具辅助开发。