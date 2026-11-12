#requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Check')]
param(
    [Parameter(ParameterSetName = 'Check')][switch]$Check,
    [Parameter(Mandatory, ParameterSetName = 'Publish')][string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$path = Join-Path $root 'SAF.json'
$manifest = [IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
if (-not $Check -and -not $Version) { throw 'Specify -Check or -Version <higher-version>.' }

function Assert-ManifestPath([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '[\\:<>"|?*\x00-\x1f]' -or
        $Relative.StartsWith('/') -or $Relative.EndsWith('/') -or @($Relative.Split('/') | Where-Object {
            $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or
            $_ -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)'
        }).Count -gt 0) { throw "Invalid manifest path: $Relative" }
}

if ($manifest.schemaVersion -ne 1 -or $manifest.frameworkVersion -notmatch '^\d+\.\d+\.\d+$' -or
    $manifest.handlerProtocolVersion -ne 1) { throw 'Unsupported SAF release manifest.' }
if (-not $Check -and ($Version -notmatch '^\d+\.\d+\.\d+$' -or [version]$Version -le [version]$manifest.frameworkVersion)) {
    throw 'Publishing requires a strictly greater stable major.minor.patch version.'
}
$targets = @{}
$changed = New-Object 'System.Collections.Generic.List[string]'
foreach ($entry in @($manifest.files)) {
    Assert-ManifestPath ([string]$entry.source)
    Assert-ManifestPath ([string]$entry.target)
    if ($targets.ContainsKey($entry.target) -or $entry.target -in @('SAF.json', 'SAF.lock.json')) { throw 'Duplicate or reserved manifest target.' }
    if ($entry.mode -eq 'managed') {
        if ($entry.target -notin @('AGENTS.md', 'origin.bat', 'local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1') -and
            -not $entry.target.StartsWith('docs-ai/common/', [StringComparison]::Ordinal) -and
            -not $entry.target.StartsWith('.agents/skills/', [StringComparison]::Ordinal)) { throw "Invalid managed target: $($entry.target)" }
    } elseif ($entry.mode -eq 'seed') {
        if ($entry.target -notin @('debug.bat', 'docs/.gitkeep') -and
            -not $entry.target.StartsWith('docs-ai/current/', [StringComparison]::Ordinal)) { throw "Invalid seed target: $($entry.target)" }
    } else { throw "Unknown file mode: $($entry.mode)" }
    $targets[$entry.target] = $entry
    $source = Join-Path $root $entry.source
    $cursor = $source
    while ($cursor -and $cursor.Length -ge $root.Length) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked manifest source: $($entry.source)" }
        if ($cursor -eq $root) { break }
        $cursor = Split-Path -Parent $cursor
    }
    if (-not [IO.File]::Exists($source)) { throw "Manifest source is not a file: $($entry.source)" }
    $text = [IO.File]::ReadAllText($source, $utf8).TrimStart([char]0xFEFF).Replace("`r`n", "`n")
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { $digest = ([BitConverter]::ToString($algorithm.ComputeHash($utf8.GetBytes($text)))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
    if ($entry.sha256 -notmatch '^[0-9a-f]{64}$' -or $digest -cne $entry.sha256) { $changed.Add([string]$entry.source) }
    $entry.sha256 = $digest
}
$expectedBootstrap = @('origin.bat', 'local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1')
$bootstrap = @($manifest.bootstrapFiles)
if (@(Compare-Object ($expectedBootstrap | Sort-Object) ($bootstrap | Sort-Object)).Count -ne 0 -or
    @($bootstrap | Select-Object -Unique).Count -ne $expectedBootstrap.Count) { throw 'Invalid bootstrap handler set.' }
foreach ($required in ($expectedBootstrap + @('AGENTS.md', 'docs-ai/common/rules.md', 'docs-ai/common/codedesign.md', 'docs-ai/common/UIUX.md'))) {
    if (-not $targets.ContainsKey($required) -or $targets[$required].mode -ne 'managed') { throw "Required managed target is absent: $required" }
}
$requiredSeeds = @('debug.bat', 'docs/.gitkeep', 'docs-ai/current/1_architecture.md', 'docs-ai/current/1_dependency.md',
    'docs-ai/current/1_changelogs/.gitkeep', 'docs-ai/current/1_bugreports/.gitkeep', 'docs-ai/current/1_archived/.gitkeep')
foreach ($required in $requiredSeeds) {
    if (-not $targets.ContainsKey($required) -or $targets[$required].mode -ne 'seed') { throw "Required project seed is absent: $required" }
}
if ($Check) {
    if ($changed.Count -gt 0) { throw ('Manifest hashes are stale: ' + ($changed -join ', ')) }
    Write-Host "SAF $($manifest.frameworkVersion) manifest and payload hashes verified."
    return
}
$manifest.frameworkVersion = $Version
$temporary = $path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
try {
    [IO.File]::WriteAllText($temporary, ($manifest | ConvertTo-Json -Depth 30) + "`n", $utf8)
    [IO.File]::Replace($temporary, $path, [NullString]::Value)
} finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
Write-Host "Prepared SAF $Version. Review the diff and run the manual acceptance checks before publishing."
