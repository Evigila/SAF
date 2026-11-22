#requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Check')]
param(
    [Parameter(ParameterSetName = 'Check')][switch]$Check,
    [Parameter(Mandatory, ParameterSetName = 'Publish')][string]$Version,
    [Parameter(ParameterSetName = 'Publish')][switch]$ReleaseApproved,
    [Parameter(ParameterSetName = 'Publish')][switch]$MajorMinorApproved
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'saf-core.ps1')
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false, $true)
function Read-PublishJsonObject([byte[]]$Bytes) {
    $text = $utf8.GetString($Bytes).TrimStart([char]0xFEFF)
    # Preserve the object-root contract on both PowerShell 5.1 and PowerShell 7.
    if ($text -notmatch '\A[ \t\r\n]*\{') { throw 'Expected a top-level JSON object.' }
    $value = if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { ConvertFrom-Json -InputObject $text -DateKind String }
        else { ConvertFrom-Json -InputObject $text }
    if ($null -eq $value -or $value -isnot [pscustomobject]) { throw 'Expected a top-level JSON object.' }
    return $value
}
$path = Get-SafTarget -Root $root -Relative '.agents/saf/SAF.json'
$manifest = Read-PublishJsonObject ([IO.File]::ReadAllBytes($path))
if (-not $Check -and -not $Version) { throw 'Specify -Check or -Version <higher-version>.' }

function Assert-ManifestPath([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '[\\:<>"|?*\x00-\x1f]' -or
        $Relative.StartsWith('/') -or $Relative.EndsWith('/') -or @($Relative.Split('/') | Where-Object {
            $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or
            $_ -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)'
        }).Count -gt 0) { throw "Invalid manifest path: $Relative" }
}

if (($manifest.schemaVersion -isnot [int] -and $manifest.schemaVersion -isnot [long]) -or $manifest.schemaVersion -ne 1 -or
    $manifest.handlerProtocolVersion -ne 4 -or
    ($manifest.handlerProtocolVersion -isnot [int] -and $manifest.handlerProtocolVersion -isnot [long]) -or
    -not $manifest.PSObject.Properties['configSupportVersion'] -or
    ($manifest.configSupportVersion -isnot [int] -and $manifest.configSupportVersion -isnot [long]) -or
    $manifest.configSupportVersion -ne 2) { throw 'Unsupported SAF 2 release manifest.' }
$currentVersion = ConvertTo-SafReleaseVersion $manifest.frameworkVersion -AllowLegacy
if ($currentVersion.Number -lt [version]'2.0.0') { throw 'Expected a SAF 2 release with numeric base >= 2.0.0.' }
if (-not $Check) {
    $candidate = ConvertTo-SafReleaseVersion $Version
    if ((Compare-SafReleaseVersion $candidate $currentVersion) -le 0) { throw 'The proposed version must advance the current release.' }
    if (($candidate.Number.Major -ne $currentVersion.Number.Major -or $candidate.Number.Minor -ne $currentVersion.Number.Minor) -and
        -not $MajorMinorApproved) { throw 'Ask the user to approve the major/minor change before supplying -MajorMinorApproved.' }
    if ($candidate.Channel -eq 'release' -and -not $ReleaseApproved) {
        throw 'Ask the user to approve the release channel before supplying -ReleaseApproved.'
    }
}
$targets = @{}
$changed = New-Object 'System.Collections.Generic.List[string]'
foreach ($entry in @($manifest.files)) {
    Assert-ManifestPath ([string]$entry.source)
    Assert-ManifestPath ([string]$entry.target)
    if ($targets.ContainsKey($entry.target) -or $entry.target -in @('.agents/saf/SAF.json', '.agents/saf/SAF.lock.json')) { throw 'Duplicate or reserved manifest target.' }
    if ($entry.mode -eq 'managed') {
        if ($entry.target -notin @('AGENTS.md', 'scripts/origin.bat', 'scripts/local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1') -and
            -not $entry.target.StartsWith('docs-ai/common/', [StringComparison]::Ordinal) -and
            -not $entry.target.StartsWith('.agents/skills/', [StringComparison]::Ordinal)) { throw "Invalid managed target: $($entry.target)" }
    } elseif ($entry.mode -eq 'seed') {
        if ($entry.target -notin @('.agents/saf/SAF.config.json', 'debug.bat', 'docs/.gitkeep') -and
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
$expectedBootstrap = @('scripts/origin.bat', 'scripts/local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1')
$bootstrap = @($manifest.bootstrapFiles)
if (@(Compare-Object ($expectedBootstrap | Sort-Object) ($bootstrap | Sort-Object)).Count -ne 0 -or
    @($bootstrap | Select-Object -Unique).Count -ne $expectedBootstrap.Count) { throw 'Invalid bootstrap handler set.' }
foreach ($required in ($expectedBootstrap + @('AGENTS.md', 'docs-ai/common/rules.md', 'docs-ai/common/codedesign.md', 'docs-ai/common/UIUX.md'))) {
    if (-not $targets.ContainsKey($required) -or $targets[$required].mode -ne 'managed') { throw "Required managed target is absent: $required" }
}
$requiredSeeds = @('.agents/saf/SAF.config.json', 'debug.bat', 'docs/.gitkeep', 'docs-ai/current/1_architecture.md', 'docs-ai/current/1_dependency.md',
    'docs-ai/current/1_changelogs/.gitkeep', 'docs-ai/current/1_bugreports/.gitkeep', 'docs-ai/current/1_archived/.gitkeep')
foreach ($required in $requiredSeeds) {
    if (-not $targets.ContainsKey($required) -or $targets[$required].mode -ne 'seed') { throw "Required project seed is absent: $required" }
}
$configEntry = $targets['.agents/saf/SAF.config.json']
if ($configEntry.source -cne 'templates/SAF.config.json') { throw 'Project configuration must use the neutral consumer template.' }
$configTemplate = Read-PublishJsonObject ([IO.File]::ReadAllBytes((Join-Path $root $configEntry.source)))
if (@($configTemplate.PSObject.Properties).Count -ne 1 -or -not $configTemplate.PSObject.Properties['schemaVersion'] -or
    ($configTemplate.schemaVersion -isnot [int] -and $configTemplate.schemaVersion -isnot [long]) -or
    $configTemplate.schemaVersion -ne 2) { throw '.agents/saf/SAF.config.json template must contain only numeric schemaVersion: 2.' }
if ($Check) {
    if ($changed.Count -gt 0) { throw ('Manifest hashes are stale: ' + ($changed -join ', ')) }
    Write-Host "SAF $($manifest.frameworkVersion) manifest and payload hashes verified."
    return
}
$config = Resolve-SafConfig -Root $root
Assert-SafWritable -Root $root -Relative '.agents/saf/SAF.json' -Config $config
$manifest.frameworkVersion = $Version
$temporary = $path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
try {
    [IO.File]::WriteAllText($temporary, ($manifest | ConvertTo-Json -Depth 30) + "`n", $utf8)
    [IO.File]::Replace($temporary, $path, [NullString]::Value)
} finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
Write-Host "Prepared SAF $Version. Review the diff and obtain confirmation of the release copy before committing or publishing."
